import { Injectable } from "@nestjs/common";
import { createHash, randomUUID } from "node:crypto";
import { ApiError, log } from "@instagpu/shared-http";
import { cfg } from "../../config";

const MAX_BODY = 1024 * 1024; // Kong allows 1 MB too
const REQUEST_HEADERS = ["content-type", "idempotency-key", "if-match"];
const RESPONSE_HEADERS = ["content-type", "content-disposition", "x-correlation-id", "x-request-id", "idempotent-replayed", "cache-control", "etag"];

export interface ProxyRequest {
  method: string;
  /** Path after /bff/api/, e.g. "v1/me". */
  path: string;
  search: string;
  headers: Record<string, string | string[] | undefined>;
  body?: Buffer;
  sessionRowId: string;
  accessToken: string;
}

/**
 * Browser -> /bff/api/v1/... -> (session + CSRF checked by guards) -> Kong /api/v1/... with the bearer token.
 * Ported from the reference console app/bff/api/[...path]. Only an allow-list of headers crosses in either direction.
 */
@Injectable()
export class ProxyService {
  async forward(r: ProxyRequest) {
    const segments = r.path.split("/");
    // Only the platform's /api/v1 routes, and no "." / ".." segments that would climb out of /api once the URL is resolved.
    if (segments[0] !== "v1" || segments.some((s) => s === "" || s === "." || s === ".." || s.includes("\\"))) {
      throw new ApiError("NOT_FOUND", "Not found.");
    }
    const url = new URL(`/api/${segments.map(encodeURIComponent).join("/")}${r.search}`, cfg().KONG_URL);
    const correlationId = randomUUID();
    const headers: Record<string, string> = {
      authorization: `Bearer ${r.accessToken}`,
      "x-correlation-id": correlationId,
      // All browser traffic reaches Kong from the BFF, so Kong rate-limits per session with this opaque key (kong.yaml).
      "x-bff-session": createHash("sha256").update(r.sessionRowId).digest("hex").slice(0, 32),
      accept: "application/json",
    };
    for (const h of REQUEST_HEADERS) {
      const v = r.headers[h];
      if (typeof v === "string") headers[h] = v;
    }
    const hasBody = !["GET", "HEAD"].includes(r.method);
    if (hasBody && r.body && r.body.length > MAX_BODY) throw new ApiError("VALIDATION_FAILED", "Request body is too large.");

    let upstream: Response;
    try {
      upstream = await fetch(url, {
        method: r.method,
        headers,
        body: hasBody && r.body?.length ? new Uint8Array(r.body) : undefined,
        signal: AbortSignal.timeout(cfg().PROXY_TIMEOUT_MS),
        redirect: "manual",
      });
    } catch (e) {
      const timedOut = (e as Error)?.name === "TimeoutError";
      log("warn", "upstream call failed", { url: url.pathname, correlation_id: correlationId, err: String((e as Error)?.message ?? e) });
      return {
        status: timedOut ? 504 : 502,
        headers: { "content-type": "application/json", "x-correlation-id": correlationId },
        body: Buffer.from(JSON.stringify({ code: "UPSTREAM_UNAVAILABLE", message: "The service did not answer. Try again.", correlation_id: correlationId, details: {} })),
      };
    }
    const out: Record<string, string> = {};
    for (const h of RESPONSE_HEADERS) {
      const v = upstream.headers.get(h);
      if (v) out[h] = v;
    }
    return { status: upstream.status, headers: out, body: Buffer.from(await upstream.arrayBuffer()) };
  }
}

import * as client from "openid-client";
import { cfg } from "../../config";

let configPromise: Promise<client.Configuration> | undefined;

/** Endpoints this service calls itself (not the browser): they must use the internal Keycloak address. */
const BACKCHANNEL = ["token_endpoint", "revocation_endpoint", "introspection_endpoint", "userinfo_endpoint", "jwks_uri"] as const;

/**
 * Keycloak metadata, cached per process. Confidential client + PKCE (S256), as in the reference console lib/oidc.ts.
 * In Docker the issuer (http://localhost:8081/...) is the browser's address and unreachable from this container, so the discovery
 * document is read from OIDC_INTERNAL_URL and the server-to-server endpoints are pointed at it. The issuer itself is kept, so ID token
 * checks still compare against what Keycloak signs.
 */
export function oidc(): Promise<client.Configuration> {
  configPromise ??= (async () => {
    const c = cfg();
    const internal = c.OIDC_INTERNAL_URL ?? c.OIDC_ISSUER;
    const res = await fetch(`${internal}/.well-known/openid-configuration`, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) throw new Error(`OIDC discovery failed: ${res.status}`);
    const meta = (await res.json()) as client.ServerMetadata & Record<string, unknown>;
    if (meta.issuer !== c.OIDC_ISSUER) throw new Error(`OIDC issuer mismatch: Keycloak says ${meta.issuer}, OIDC_ISSUER is ${c.OIDC_ISSUER}`);
    const publicOrigin = new URL(c.OIDC_ISSUER).origin;
    const internalOrigin = new URL(internal).origin;
    for (const k of BACKCHANNEL) {
      const v = meta[k];
      if (typeof v === "string" && v.startsWith(publicOrigin)) (meta as Record<string, unknown>)[k] = internalOrigin + v.slice(publicOrigin.length);
    }
    const config = new client.Configuration(meta, c.OIDC_CLIENT_ID, c.OIDC_CLIENT_SECRET);
    if (internal.startsWith("http://") || c.OIDC_ISSUER.startsWith("http://")) {
      if (c.NODE_ENV === "production") throw new Error("OIDC over plain http is not allowed in production");
      client.allowInsecureRequests(config);
    }
    return config;
  })().catch((e) => {
    configPromise = undefined; // retry on the next request (Keycloak may still be starting)
    throw e;
  });
  return configPromise;
}
export { client };

import { NotFoundException } from "@nestjs/common";
import { describe, expect, it } from "vitest";
import { ApiError, ErrorEnvelopeFilter } from "./error.filter";

function run(exception: unknown) {
  let status = 0;
  let body: Record<string, unknown> = {};
  const res = { status: (s: number) => ((status = s), res), json: (b: Record<string, unknown>) => (body = b) };
  const req = { requestId: "req-1", correlationId: "corr-1" };
  const host = { switchToHttp: () => ({ getResponse: () => res, getRequest: () => req }) };
  new ErrorEnvelopeFilter().catch(exception, host as never);
  return { status, body };
}

describe("ErrorEnvelopeFilter", () => {
  it("maps ApiError to its status and code", () => {
    expect(run(new ApiError("FORBIDDEN", "No.", { required: ["admin"] }))).toEqual({
      status: 403,
      body: { code: "FORBIDDEN", message: "No.", request_id: "req-1", correlation_id: "corr-1", details: { required: ["admin"] } },
    });
  });
  it("maps Nest HTTP exceptions to the envelope", () => {
    expect(run(new NotFoundException("Cannot GET /x")).body).toMatchObject({ code: "NOT_FOUND", message: "Cannot GET /x" });
  });
  it("hides unexpected errors behind INTERNAL", () => {
    const { status, body } = run(new Error("db password is wrong"));
    expect(status).toBe(500);
    expect(body.code).toBe("INTERNAL");
    expect(JSON.stringify(body)).not.toContain("password");
  });
});

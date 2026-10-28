import "reflect-metadata";
import { Reflector } from "@nestjs/core";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK } from "jose";
import { beforeAll, describe, expect, it } from "vitest";
import { JwtAuthGuard } from "./jwt.guard";
import type { PrincipalResolver, ResolvedPerson } from "./principal-resolver";
import { Public } from "./public.decorator";
import { Roles } from "./roles.decorator";

const ISS = "http://localhost:8081/realms/instagpu";
const AUD = "instagpu-api";

class Handlers {
  open() {}
  any() {}
  ownersOnly() {}
}
Public()(Handlers.prototype, "open", Object.getOwnPropertyDescriptor(Handlers.prototype, "open")!);
Roles("cafe_owner")(Handlers.prototype, "ownersOnly", Object.getOwnPropertyDescriptor(Handlers.prototype, "ownersOnly")!);

let key: CryptoKey;
let jwk: JWK;
const people: Record<string, ResolvedPerson> = {
  "sub-owner": { userId: "u-owner", status: "ACTIVE", memberships: [{ tenantId: "t1", role: "CAFE_OWNER", branchId: null }] },
  "sub-off": { userId: "u-off", status: "DISABLED", memberships: [] },
};
const resolver: PrincipalResolver = { resolve: async ({ sub }) => people[sub] ?? null };

beforeAll(async () => {
  const pair = await generateKeyPair("RS256", { extractable: true });
  key = pair.privateKey;
  jwk = { ...(await exportJWK(pair.publicKey)), kid: "k1", alg: "RS256" };
});

const token = (claims: Record<string, unknown>, opts: { iss?: string; aud?: string; exp?: string | number; signWith?: CryptoKey } = {}) =>
  new SignJWT({ typ: "Bearer", ...claims })
    .setProtectedHeader({ alg: "RS256", kid: "k1" })
    .setIssuer(opts.iss ?? ISS)
    .setAudience(opts.aud ?? AUD)
    .setIssuedAt()
    .setExpirationTime(opts.exp ?? "5m")
    .sign(opts.signWith ?? key);

async function call(handler: keyof Handlers, authorization?: string) {
  const guard = new JwtAuthGuard(new Reflector(), { issuer: ISS, audience: AUD, keys: createLocalJWKSet({ keys: [jwk] }) }, resolver);
  const req: Record<string, unknown> = { headers: authorization ? { authorization } : {} };
  const ctx = { getHandler: () => Handlers.prototype[handler], getClass: () => Handlers, switchToHttp: () => ({ getRequest: () => req }) };
  try {
    await guard.canActivate(ctx as never);
    return { status: 200, principal: req.principal as Record<string, unknown> };
  } catch (e) {
    return { status: (e as { status: number }).status, code: (e as { code: string }).code };
  }
}

describe("JwtAuthGuard", () => {
  it("lets @Public() handlers through without a token", async () => {
    expect((await call("open")).status).toBe(200);
  });
  it("denies by default: no token, garbage, wrong issuer, wrong audience, expired, foreign key -> 401", async () => {
    expect(await call("any")).toMatchObject({ status: 401, code: "UNAUTHENTICATED" });
    expect((await call("any", "Bearer not-a-jwt")).status).toBe(401);
    expect((await call("any", `Bearer ${await token({ sub: "sub-owner" }, { iss: "http://evil/realms/instagpu" })}`)).status).toBe(401);
    expect((await call("any", `Bearer ${await token({ sub: "sub-owner" }, { aud: "instagpu-internal" })}`)).status).toBe(401);
    expect((await call("any", `Bearer ${await token({ sub: "sub-owner" }, { exp: Math.floor(Date.now() / 1000) - 120 })}`)).status).toBe(401);
    const other = (await generateKeyPair("RS256")).privateKey;
    expect((await call("any", `Bearer ${await token({ sub: "sub-owner" }, { signWith: other })}`)).status).toBe(401);
  });
  it("rejects a non-Bearer token type (e.g. an ID token) and an unknown person", async () => {
    expect((await call("any", `Bearer ${await token({ sub: "sub-owner", typ: "ID" })}`)).status).toBe(401);
    expect((await call("any", `Bearer ${await token({ sub: "sub-nobody" })}`)).status).toBe(401);
  });
  it("forbids a disabled user", async () => {
    expect(await call("any", `Bearer ${await token({ sub: "sub-off", realm_access: { roles: ["cafe_owner"] } })}`)).toMatchObject({ status: 403, code: "FORBIDDEN" });
  });
  it("builds the principal: own role, inherited roles, memberships", async () => {
    const res = await call("any", `Bearer ${await token({ sub: "sub-owner", email: "o@x.my", name: "Jason Wong", realm_access: { roles: ["cafe_owner", "offline_access"] } })}`);
    expect(res.status).toBe(200);
    expect(res.principal).toMatchObject({ userId: "u-owner", email: "o@x.my", name: "Jason Wong", role: "cafe_owner", memberships: [{ tenantId: "t1" }] });
    expect((res.principal!.roles as string[]).sort()).toEqual(["cafe_owner", "manager"]);
  });
  it("enforces @Roles() with inheritance: manager 403, owner 200, super_admin 200", async () => {
    people["sub-mgr"] = { userId: "u-mgr", status: "ACTIVE", memberships: [] };
    people["sub-sa"] = { userId: "u-sa", status: "ACTIVE", memberships: [] };
    expect((await call("ownersOnly", `Bearer ${await token({ sub: "sub-mgr", realm_access: { roles: ["manager"] } })}`)).status).toBe(403);
    expect((await call("ownersOnly", `Bearer ${await token({ sub: "sub-owner", realm_access: { roles: ["cafe_owner"] } })}`)).status).toBe(200);
    expect((await call("ownersOnly", `Bearer ${await token({ sub: "sub-sa", realm_access: { roles: ["super_admin"] } })}`)).status).toBe(200);
  });
});

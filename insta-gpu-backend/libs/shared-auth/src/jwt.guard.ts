import { CanActivate, ExecutionContext, Inject, Injectable } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { createRemoteJWKSet, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "jose";
import { ApiError } from "@instagpu/shared-http";
import { impliedRoles, knownRoles, primaryRole, type Principal, type Role } from "./principal";
import { AUTH_OPTIONS, PRINCIPAL_RESOLVER, type PrincipalResolver } from "./principal-resolver";
import { PUBLIC_KEY } from "./public.decorator";
import { ROLES_KEY } from "./roles.decorator";

export interface AuthOptions {
  issuer: string;
  audience: string;
  /** Defaults to <issuer>/protocol/openid-connect/certs. In Docker: the keycloak:8081 address (the issuer is the browser's address). */
  jwksUrl?: string;
  /** Tests: a local key set instead of fetching Keycloak's. */
  keys?: JWTVerifyGetKey;
}

type Claims = JWTPayload & { realm_access?: { roles?: string[] }; email?: string; name?: string; preferred_username?: string; typ?: string };

/**
 * Ported from InstaGPU-GC-Core shared/auth/jwt.guard.ts. Kong does not check tokens (ADR-005): every service runs this guard globally.
 * Deny by default: signature (JWKS, cached) -> iss -> aud -> exp/nbf -> sub -> token type -> known, active person -> @Roles().
 * Only @Public() handlers (health checks) skip it.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  private readonly keys: JWTVerifyGetKey;

  constructor(
    private readonly reflector: Reflector,
    @Inject(AUTH_OPTIONS) private readonly opts: AuthOptions,
    @Inject(PRINCIPAL_RESOLVER) private readonly resolver: PrincipalResolver,
  ) {
    this.keys =
      opts.keys ??
      createRemoteJWKSet(new URL(opts.jwksUrl ?? `${opts.issuer}/protocol/openid-connect/certs`), { cooldownDuration: 30_000, cacheMaxAge: 10 * 60_000 });
  }

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(PUBLIC_KEY, targets)) return true;

    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) throw new ApiError("UNAUTHENTICATED", "Missing bearer token.");

    let claims: Claims;
    try {
      ({ payload: claims } = await jwtVerify<Claims>(header.slice(7), this.keys, { issuer: this.opts.issuer, audience: this.opts.audience, clockTolerance: 30 }));
    } catch {
      throw new ApiError("UNAUTHENTICATED", "Invalid or expired token.");
    }
    if (!claims.sub) throw new ApiError("UNAUTHENTICATED", "Token has no subject.");
    if (claims.typ && claims.typ !== "Bearer") throw new ApiError("UNAUTHENTICATED", "Wrong token type.");

    const own = knownRoles(claims.realm_access?.roles ?? []);
    const name = claims.name ?? claims.preferred_username;
    const person = await this.resolver.resolve({ sub: claims.sub, email: claims.email, name });
    if (!person) throw new ApiError("UNAUTHENTICATED", "This login is not known to the platform yet. Sign in again.");
    if (person.status !== "ACTIVE") throw new ApiError("FORBIDDEN", "This user is disabled.");

    const principal: Principal = {
      userId: person.userId,
      sub: claims.sub,
      email: claims.email,
      name,
      role: primaryRole(own),
      roles: impliedRoles(own),
      memberships: person.memberships,
    };
    req.principal = principal;

    const required = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, targets);
    if (required?.length && !required.some((r) => principal.roles.includes(r))) {
      throw new ApiError("FORBIDDEN", "Your role does not allow this action.", { required });
    }
    return true;
  }
}

import type { Membership } from "./principal";

/** What a verified token tells us about the person (identity only; never cafe scope). */
export interface TokenIdentity {
  sub: string;
  email?: string;
  name?: string;
}

/** The person as the platform knows them: database id, status and active memberships. */
export interface ResolvedPerson {
  userId: string;
  status: "ACTIVE" | "DISABLED" | "PENDING";
  memberships: Membership[];
}

/**
 * sub -> person. auth-service implements it against identity.users / core.tenant_memberships (and upserts the user on first login);
 * other services implement it by asking auth-service (GET /internal/principals/:sub, cached 30 s). Returns null when unknown.
 */
export interface PrincipalResolver {
  resolve(identity: TokenIdentity): Promise<ResolvedPerson | null>;
}

export const PRINCIPAL_RESOLVER = Symbol("PRINCIPAL_RESOLVER");
export const AUTH_OPTIONS = Symbol("AUTH_OPTIONS");

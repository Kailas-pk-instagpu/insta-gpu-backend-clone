import { ApiError } from "@instagpu/shared-http";
import { canAccessBranch, isPlatformStaff, type Principal } from "./principal";

/**
 * Scope checks (ported from the reference shared/scope.ts). Out of scope answers 404, never 403, so ids cannot be probed:
 * "not yours" and "does not exist" look the same. The database lookups live in each service's repository (RLS through withTx);
 * these helpers decide on the row it found.
 */
export function notFound(what: string): never {
  throw new ApiError("NOT_FOUND", `${what} not found.`);
}

/** The withTx scope to look a row up in: platform staff see every cafe, everyone else one candidate per cafe they belong to. */
export function scopeCandidates(p: Principal): Array<{ tenantId?: string; platformScope?: boolean }> {
  return isPlatformStaff(p) ? [{ platformScope: true }] : [...new Set(p.memberships.map((m) => m.tenantId))].map((tenantId) => ({ tenantId }));
}

/** Throws 404 unless the caller may act in this cafe. */
export function assertTenantInScope(p: Principal, tenantId: string): void {
  if (!isPlatformStaff(p) && !p.memberships.some((m) => m.tenantId === tenantId)) notFound("Cafe");
}

/** Throws 404 unless the caller may act on this branch of this cafe. */
export function assertBranchInScope(p: Principal, tenantId: string, branchId: string): void {
  if (!canAccessBranch(p, tenantId, branchId)) notFound("Branch");
}

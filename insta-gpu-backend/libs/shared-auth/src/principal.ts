/**
 * Realm roles in Keycloak realm "instagpu" (ADR-014: the frontend's four). Ported from InstaGPU-GC-Core shared/auth/principal.ts.
 * Higher roles INHERIT what the roles below them may do, so when a Floor Manager cannot do something the owner or super admin can:
 *
 *   super_admin -> admin (Sales Manager)
 *               -> cafe_owner -> manager (Floor Manager)      (cafe roles are further limited to their cafe / branch by membership)
 *
 * Inheritance is applied once, when the principal is built (impliedRoles), so a route lists the LOWEST role that may use it.
 * Platform staff (super_admin, admin) see every cafe (ADR-014); what they may DO is decided per route.
 */
export const PLATFORM_ROLES = ["super_admin", "admin"] as const;
export const CAFE_ROLES = ["cafe_owner", "manager"] as const;
export const ALL_ROLES = [...PLATFORM_ROLES, ...CAFE_ROLES] as const;
export type Role = (typeof ALL_ROLES)[number];

const IMPLIES: Record<Role, readonly Role[]> = {
  super_admin: ["admin", "cafe_owner", "manager"],
  admin: [],
  cafe_owner: ["manager"],
  manager: [],
};

/** Highest first: the role the frontend shows for a person (User.role). */
const RANK: readonly Role[] = ["super_admin", "admin", "cafe_owner", "manager"];

/** The roles a person effectively has: their own plus everything those roles inherit. */
export function impliedRoles(roles: readonly Role[]): Role[] {
  const out = new Set<Role>(roles);
  for (const r of roles) for (const i of IMPLIES[r]) out.add(i);
  return [...out];
}

/** Keep only realm roles we know (Keycloak also puts offline_access, default-roles-instagpu, ... in the token). */
export function knownRoles(raw: readonly string[]): Role[] {
  return raw.filter((r): r is Role => (ALL_ROLES as readonly string[]).includes(r));
}

/** The person's own highest role (before inheritance), or null when the token has none of ours. */
export function primaryRole(roles: readonly Role[]): Role | null {
  return RANK.find((r) => roles.includes(r)) ?? null;
}

/** Membership roles in core.tenant_memberships: cafe_owner -> CAFE_OWNER (whole cafe), manager -> BRANCH_MANAGER (one row per branch). */
export interface Membership {
  tenantId: string;
  role: "CAFE_OWNER" | "BRANCH_MANAGER";
  branchId: string | null; // null = all branches of the tenant
}

/**
 * Who is calling. Tenancy does NOT come from the token: Keycloak only proves identity + realm role,
 * auth-service resolves sub -> identity.users -> core.tenant_memberships.
 */
export interface Principal {
  userId: string;
  sub: string;
  email?: string;
  name?: string;
  /** Own highest realm role (what the frontend shows). */
  role: Role | null;
  /** Effective roles (own + inherited): what @Roles() checks. */
  roles: Role[];
  memberships: Membership[];
}

/** InstaGPU staff who act across cafes. */
export const isPlatformStaff = (p: Pick<Principal, "roles">) => p.roles.some((r) => (PLATFORM_ROLES as readonly string[]).includes(r));

/** Tenants the caller may act in ('*' = all, platform staff only). */
export function tenantScope(p: Principal): "*" | string[] {
  if (isPlatformStaff(p)) return "*";
  return [...new Set(p.memberships.map((m) => m.tenantId))];
}

/** Is the caller an owner of this tenant (membership, not just the realm role)? Super admins always pass. */
export function isTenantOwner(p: Principal, tenantId: string): boolean {
  return p.roles.includes("super_admin") || p.memberships.some((m) => m.tenantId === tenantId && m.role === "CAFE_OWNER");
}

/** Can the caller act on this branch? Staff: any. Owners: any branch of their cafe. Floor Managers: their branches only. */
export function canAccessBranch(p: Principal, tenantId: string, branchId: string): boolean {
  if (isPlatformStaff(p)) return true;
  return p.memberships.some((m) => m.tenantId === tenantId && (m.role === "CAFE_OWNER" || m.branchId === null || m.branchId === branchId));
}

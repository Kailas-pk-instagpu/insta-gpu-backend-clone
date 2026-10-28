import { describe, expect, it } from "vitest";
import { canAccessBranch, impliedRoles, isPlatformStaff, isTenantOwner, knownRoles, primaryRole, tenantScope, type Principal } from "./principal";

const who = (roles: Parameters<typeof impliedRoles>[0], memberships: Principal["memberships"] = []): Principal => ({
  userId: "u", sub: "s", role: primaryRole(roles), roles: impliedRoles(roles), memberships,
});

describe("role inheritance (ADR-014)", () => {
  it("manager < cafe_owner; super_admin inherits every role; admin inherits nothing", () => {
    expect(impliedRoles(["manager"])).toEqual(["manager"]);
    expect(impliedRoles(["cafe_owner"]).sort()).toEqual(["cafe_owner", "manager"]);
    expect(impliedRoles(["super_admin"]).sort()).toEqual(["admin", "cafe_owner", "manager", "super_admin"]);
    expect(impliedRoles(["admin"])).toEqual(["admin"]);
  });
  it("nobody inherits super_admin, and a cafe role never grants a platform role", () => {
    for (const r of ["admin", "cafe_owner", "manager"] as const) expect(impliedRoles([r])).not.toContain("super_admin");
    expect(impliedRoles(["cafe_owner"])).not.toContain("admin");
  });
  it("drops Keycloak's own roles and picks the highest own role for the frontend", () => {
    expect(knownRoles(["offline_access", "default-roles-instagpu", "cafe_owner"])).toEqual(["cafe_owner"]);
    expect(primaryRole(["manager", "cafe_owner"])).toBe("cafe_owner");
    expect(primaryRole([])).toBeNull();
  });
});

describe("scope", () => {
  const owner = who(["cafe_owner"], [{ tenantId: "t1", role: "CAFE_OWNER", branchId: null }]);
  const manager = who(["manager"], [{ tenantId: "t1", role: "BRANCH_MANAGER", branchId: "b1" }]);

  it("super_admin and admin (Sales Manager) see every cafe; cafe roles only their own", () => {
    expect(isPlatformStaff(who(["super_admin"]))).toBe(true);
    expect(isPlatformStaff(who(["admin"]))).toBe(true);
    expect(tenantScope(who(["admin"]))).toBe("*");
    expect(isPlatformStaff(owner)).toBe(false);
    expect(tenantScope(owner)).toEqual(["t1"]);
  });
  it("an owner reaches every branch of their cafe; a Floor Manager only their branch", () => {
    expect(canAccessBranch(owner, "t1", "b2")).toBe(true);
    expect(canAccessBranch(owner, "t2", "b9")).toBe(false);
    expect(canAccessBranch(manager, "t1", "b1")).toBe(true);
    expect(canAccessBranch(manager, "t1", "b2")).toBe(false);
  });
  it("owner checks use the membership, not the realm role", () => {
    expect(isTenantOwner(owner, "t1")).toBe(true);
    expect(isTenantOwner(who(["cafe_owner"]), "t1")).toBe(false);
    expect(isTenantOwner(who(["super_admin"]), "t1")).toBe(true);
  });
});

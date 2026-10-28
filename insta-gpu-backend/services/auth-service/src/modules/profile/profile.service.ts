import { Injectable } from "@nestjs/common";
import { ApiError } from "@instagpu/shared-http";
import { tenantScope, type Principal } from "@instagpu/shared-auth";
import { UsersService } from "../users/users.service";

@Injectable()
export class ProfileService {
  constructor(private readonly users: UsersService) {}

  async me(p: Principal) {
    const u = await this.users.findById(p.userId);
    if (!u) throw new ApiError("NOT_FOUND", "User not found.");
    return {
      user_id: u.id,
      sub: p.sub,
      email: u.email ?? p.email ?? null,
      name: u.display_name ?? p.name ?? null,
      /** Own highest realm role: super_admin | admin (Sales Manager) | cafe_owner | manager (Floor Manager). */
      role: p.role,
      /** Effective roles (own + inherited). */
      roles: p.roles,
      /** '*' for platform staff (every cafe), otherwise the cafe ids the person belongs to. */
      tenant_scope: tenantScope(p),
      memberships: p.memberships.map((m) => ({ tenant_id: m.tenantId, role: m.role, branch_id: m.branchId })),
      phone: u.phone,
      address: u.address,
      has_avatar: u.has_avatar,
      created_by: u.created_by,
      created_at: u.created_at,
    };
  }
}

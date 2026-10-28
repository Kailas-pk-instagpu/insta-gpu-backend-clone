import { Injectable } from "@nestjs/common";
import { getDb } from "@instagpu/shared-db";
import type { Membership, ResolvedPerson, TokenIdentity } from "@instagpu/shared-auth";

// SQL for this module's tables only (identity.users; memberships through the SECURITY DEFINER lookup).
@Injectable()
export class UsersRepository {
  /**
   * First login creates identity.users by Keycloak sub (ported from the reference guard). Later logins keep the e-mail in step with
   * Keycloak and fill the display name only while it is empty (the person may have edited it in their profile).
   */
  async upsertBySub(identity: TokenIdentity): Promise<{ id: string; status: ResolvedPerson["status"] }> {
    const { rows } = await getDb().query<{ id: string; status: ResolvedPerson["status"] }>(
      `INSERT INTO identity.users (keycloak_subject, email, display_name) VALUES ($1, $2, $3)
       ON CONFLICT (keycloak_subject) DO UPDATE
         SET email = COALESCE(EXCLUDED.email, identity.users.email),
             display_name = COALESCE(identity.users.display_name, EXCLUDED.display_name),
             updated_at = now()
         WHERE identity.users.email IS DISTINCT FROM COALESCE(EXCLUDED.email, identity.users.email)
            OR (identity.users.display_name IS NULL AND EXCLUDED.display_name IS NOT NULL)
       RETURNING id, status`,
      [identity.sub, identity.email ?? null, identity.name ?? null],
    );
    if (rows[0]) return rows[0];
    // Nothing changed (the usual case): no write, just read.
    const { rows: existing } = await getDb().query<{ id: string; status: ResolvedPerson["status"] }>(
      `SELECT id, status FROM identity.users WHERE keycloak_subject = $1`,
      [identity.sub],
    );
    return existing[0];
  }

  /** Active memberships of ACTIVE / SUSPENDED cafes. Memberships are under RLS and no cafe is known yet, so this goes through core.active_memberships_of. */
  async activeMemberships(userId: string): Promise<Membership[]> {
    const { rows } = await getDb().query<{ tenant_id: string; role: string; branch_id: string | null }>(
      `SELECT tenant_id, role, branch_id FROM core.active_memberships_of($1)`,
      [userId],
    );
    return rows
      .filter((r): r is { tenant_id: string; role: Membership["role"]; branch_id: string | null } => r.role === "CAFE_OWNER" || r.role === "BRANCH_MANAGER")
      .map((r) => ({ tenantId: r.tenant_id, role: r.role, branchId: r.branch_id }));
  }

  async findById(id: string) {
    const { rows } = await getDb().query<{
      id: string; email: string | null; display_name: string | null; phone: string | null; address: string | null;
      status: string; created_by: string | null; created_at: Date; has_avatar: boolean;
    }>(
      `SELECT u.id, u.email, u.display_name, u.phone, u.address, u.status, u.created_by, u.created_at,
              EXISTS (SELECT 1 FROM identity.user_avatars a WHERE a.user_id = u.id) AS has_avatar
       FROM identity.users u WHERE u.id = $1`,
      [id],
    );
    return rows[0] ?? null;
  }
}

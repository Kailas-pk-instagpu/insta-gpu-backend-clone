import { Injectable } from "@nestjs/common";
import { getDb, type Tx } from "@instagpu/shared-db";

export interface SessionRow {
  id: string;
  user_id: string;
  refresh_token_ciphertext: string;
  metadata: { sid_hash: string; access: string; access_exp: number; id_token?: string | null };
}

/** SQL for identity.bff_sessions only (DB login app_bff_login). Ported from the reference console lib/session-store.ts. */
@Injectable()
export class SessionRepository {
  async insert(s: { userId: string; refreshCipher: string; csrfHash: string; maxHours: number; userAgentHash: string; metadata: SessionRow["metadata"] }) {
    await getDb().query(
      `INSERT INTO identity.bff_sessions (user_id, refresh_token_ciphertext, csrf_token_hash, expires_at, user_agent_hash, metadata)
       VALUES ($1, $2, $3, now() + ($4 || ' hours')::interval, $5, $6)`,
      [s.userId, s.refreshCipher, s.csrfHash, String(s.maxHours), s.userAgentHash, s.metadata],
    );
  }

  /** By hash of the cookie value; enforces revocation, absolute expiry and idle timeout, and records activity. */
  async touch(sidHash: string, idleMinutes: number): Promise<{ id: string; user_id: string } | null> {
    const { rows } = await getDb().query<{ id: string; user_id: string }>(
      `UPDATE identity.bff_sessions SET last_seen_at = now()
       WHERE metadata->>'sid_hash' = $1 AND revoked_at IS NULL AND expires_at > now()
         AND last_seen_at > now() - ($2 || ' minutes')::interval
       RETURNING id, user_id`,
      [sidHash, String(idleMinutes)],
    );
    return rows[0] ?? null;
  }

  async csrfMatches(rowId: string, csrfHash: string): Promise<boolean> {
    const { rows } = await getDb().query(`SELECT 1 FROM identity.bff_sessions WHERE id = $1 AND csrf_token_hash = $2`, [rowId, csrfHash]);
    return rows.length === 1;
  }

  /** Row lock: two BFF copies refreshing the same session at once would otherwise trip Keycloak's refresh-token reuse detection. */
  async lockForRefresh(tx: Tx, rowId: string): Promise<SessionRow | null> {
    const { rows } = await tx.query<SessionRow>(
      `SELECT id, user_id, refresh_token_ciphertext, metadata FROM identity.bff_sessions WHERE id = $1 AND revoked_at IS NULL FOR UPDATE`,
      [rowId],
    );
    return rows[0] ?? null;
  }

  async saveRefreshed(tx: Tx, rowId: string, refreshCipher: string, access: string, accessExp: number) {
    await tx.query(
      `UPDATE identity.bff_sessions SET refresh_token_ciphertext = $2, metadata = metadata || $3::jsonb WHERE id = $1`,
      [rowId, refreshCipher, JSON.stringify({ access, access_exp: accessExp })],
    );
  }

  async revoke(rowId: string): Promise<Pick<SessionRow, "refresh_token_ciphertext" | "metadata"> | null> {
    const { rows } = await getDb().query<SessionRow>(
      `UPDATE identity.bff_sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL RETURNING refresh_token_ciphertext, metadata`,
      [rowId],
    );
    return rows[0] ?? null;
  }
}

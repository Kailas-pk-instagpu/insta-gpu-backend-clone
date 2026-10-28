import { Injectable } from "@nestjs/common";
import { withTx } from "@instagpu/shared-db";
import { log } from "@instagpu/shared-http";
import { cfg } from "../../config";
import { decrypt, encrypt, randomToken, sha256 } from "./crypto";
import { client, oidc } from "./oidc";
import { SessionRepository } from "./session.repository";

export interface BffSession {
  rowId: string;
  userId: string;
}

/**
 * Server-side BFF sessions (ported from the reference console lib/session-store.ts). The browser holds only an opaque random
 * session id (HttpOnly cookie) and a CSRF token; access and refresh tokens stay here, encrypted.
 */
@Injectable()
export class SessionService {
  constructor(private readonly repo: SessionRepository) {}

  async create(userId: string, tokens: client.TokenEndpointResponse & client.TokenEndpointResponseHelpers, userAgent: string) {
    const id = randomToken(32);
    const csrf = randomToken(24);
    await this.repo.insert({
      userId,
      refreshCipher: encrypt(tokens.refresh_token ?? ""),
      csrfHash: sha256(csrf),
      maxHours: cfg().SESSION_MAX_HOURS,
      userAgentHash: sha256(userAgent),
      metadata: { sid_hash: sha256(id), access: encrypt(tokens.access_token), access_exp: expiry(tokens), id_token: tokens.id_token ?? null },
    });
    return { id, csrf };
  }

  async get(cookieValue: string | undefined): Promise<BffSession | null> {
    if (!cookieValue) return null;
    const row = await this.repo.touch(sha256(cookieValue), cfg().SESSION_IDLE_MINUTES);
    return row ? { rowId: row.id, userId: row.user_id } : null;
  }

  checkCsrf(rowId: string, token: string | undefined): Promise<boolean> {
    return token ? this.repo.csrfMatches(rowId, sha256(token)) : Promise.resolve(false);
  }

  /** A valid access token for the session, refreshed under a row lock when it expires within 30 s. null = sign in again. */
  async accessToken(rowId: string): Promise<string | null> {
    try {
      return await withTx({}, async (tx) => {
        const s = await this.repo.lockForRefresh(tx, rowId);
        if (!s) return null;
        if (Number(s.metadata.access_exp) - Date.now() > 30_000) return decrypt(s.metadata.access);
        const oldRefresh = decrypt(s.refresh_token_ciphertext);
        const fresh = await client.refreshTokenGrant(await oidc(), oldRefresh);
        await this.repo.saveRefreshed(tx, rowId, encrypt(fresh.refresh_token ?? oldRefresh), encrypt(fresh.access_token), expiry(fresh));
        return fresh.access_token;
      });
    } catch (e) {
      log("warn", "session refresh failed, signing out", { err: String((e as Error)?.message ?? e) });
      await this.repo.revoke(rowId); // refresh token rejected (expired, revoked, Keycloak session ended) -> log in again
      return null;
    }
  }

  /** Revokes the BFF session and returns what is needed to end the Keycloak session too. */
  async revoke(rowId: string): Promise<{ refreshToken?: string; idToken?: string }> {
    const s = await this.repo.revoke(rowId);
    if (!s) return {};
    let refreshToken: string | undefined;
    try {
      refreshToken = decrypt(s.refresh_token_ciphertext) || undefined;
    } catch {
      refreshToken = undefined;
    }
    return { refreshToken, idToken: s.metadata?.id_token ?? undefined };
  }
}

const expiry = (t: client.TokenEndpointResponseHelpers) => Date.now() + (t.expiresIn() ?? 60) * 1000;

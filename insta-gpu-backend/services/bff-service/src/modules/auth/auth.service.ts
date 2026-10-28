import { Injectable } from "@nestjs/common";
import { log } from "@instagpu/shared-http";
import { cfg } from "../../config";
import { seal, unseal } from "../session/crypto";
import { client, oidc } from "../session/oidc";
import { SessionService } from "../session/session.service";
import { safeReturnTo } from "./safe-redirect";

export interface LoginFlow {
  verifier: string;
  state: string;
  returnTo: string;
}

/** Why a login failed, in the server log only (never tokens, codes or cookies). */
const why = (reason: string, extra: Record<string, unknown> = {}) => log("warn", "login failed", { reason, ...extra });

/** OIDC Authorization Code + PKCE (ported from the reference console app/auth/{login,callback,logout}). */
@Injectable()
export class AuthService {
  constructor(private readonly sessions: SessionService) {}

  /** Step 1: the Keycloak URL to send the browser to, and the sealed state + PKCE verifier for this attempt's own cookie. */
  async start(returnTo: string | undefined, action?: string) {
    const config = await oidc();
    const verifier = client.randomPKCECodeVerifier();
    const state = client.randomState();
    const url = client.buildAuthorizationUrl(config, {
      redirect_uri: cfg().OIDC_REDIRECT_URI,
      scope: "openid profile email",
      code_challenge: await client.calculatePKCECodeChallenge(verifier),
      code_challenge_method: "S256",
      state,
      // ?action=password: Keycloak's own "update password" step; passwords never touch the BFF or the frontend.
      ...(action === "password" ? { kc_action: "UPDATE_PASSWORD" } : {}),
    });
    const flow: LoginFlow = { verifier, state, returnTo: safeReturnTo(returnTo, cfg().FRONTEND_URL) };
    return { url: url.href, state, sealed: seal(flow) };
  }

  /**
   * Step 2: Keycloak sent the browser back. Exchange the code (verifier + state check), ask auth-service who this is through Kong
   * (it creates identity.users on first login), then create the BFF session. Returns where to send the browser.
   */
  async finish(query: string, sealedFlow: string | undefined, userAgent: string) {
    const fe = cfg().FRONTEND_URL;
    const flow = unseal<LoginFlow>(sealedFlow ?? "");
    if (!flow) {
      why("login_cookie_missing_or_unreadable");
      return { redirect: `${fe}/login?error=login_expired` };
    }
    const config = await oidc();
    let tokens;
    try {
      tokens = await client.authorizationCodeGrant(config, new URL(`${cfg().OIDC_REDIRECT_URI}${query}`), {
        pkceCodeVerifier: flow.verifier,
        expectedState: flow.state,
      });
    } catch (e) {
      why("token_exchange_failed", { err: String((e as Error)?.message ?? e) });
      return { redirect: `${fe}/login?error=login_failed` };
    }
    const me = await fetch(`${cfg().KONG_URL}/api/v1/me`, {
      headers: { authorization: `Bearer ${tokens.access_token}`, accept: "application/json" },
      signal: AbortSignal.timeout(cfg().PROXY_TIMEOUT_MS),
    }).catch((e: Error) => e);
    if (me instanceof Error || !me.ok) {
      why("api_me_rejected", me instanceof Error ? { err: me.message } : { status: me.status, body: (await me.text()).slice(0, 300) });
      return { redirect: `${fe}/login?error=not_provisioned` };
    }
    const { user_id } = (await me.json()) as { user_id: string };
    const session = await this.sessions.create(user_id, tokens, userAgent);
    return { redirect: `${fe}${flow.returnTo}`, session };
  }

  /** Ends the BFF session and the Keycloak session; returns Keycloak's logout URL for the browser (then back to the login page). */
  async logout(rowId: string | undefined) {
    const config = await oidc();
    const after = `${cfg().FRONTEND_URL}/login`;
    if (!rowId) return after;
    const { refreshToken, idToken } = await this.sessions.revoke(rowId);
    if (refreshToken) await client.tokenRevocation(config, refreshToken).catch(() => undefined);
    return client.buildEndSessionUrl(config, { post_logout_redirect_uri: after, client_id: cfg().OIDC_CLIENT_ID, ...(idToken ? { id_token_hint: idToken } : {}) }).href;
  }
}

import { Controller, Get, HttpCode, Post, Query, Req, Res, UseGuards } from "@nestjs/common";
import { createHash } from "node:crypto";
import type { CookieOptions, Request, Response } from "express";
import { cfg, csrfCookieName, loginCookiePrefix, sessionCookieName } from "../../config";
import { CsrfGuard } from "../../guards/csrf.guard";
import { SessionGuard, type SessionRequest } from "../../guards/session.guard";
import { AuthService } from "./auth.service";

/** One login cookie PER attempt (named after its state), so several tabs signing in at once do not overwrite each other (reference). */
const flowCookie = (state: string) => `${loginCookiePrefix()}${createHash("sha256").update(state).digest("hex").slice(0, 16)}`;
const base = (): CookieOptions => ({ secure: cfg().COOKIE_SECURE, path: "/" });

@Controller("bff/auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** GET /bff/auth/login?returnTo=/branches -> 302 to Keycloak (code + PKCE). */
  @Get("login")
  async login(@Query("returnTo") returnTo: string | undefined, @Query("action") action: string | undefined, @Res() res: Response) {
    const { url, state, sealed } = await this.auth.start(returnTo, action);
    res.cookie(flowCookie(state), sealed, { ...base(), httpOnly: true, sameSite: "lax", maxAge: 600_000 });
    res.redirect(302, url);
  }

  /** GET /bff/auth/callback?code&state -> session cookie + CSRF cookie -> 302 to the frontend. */
  @Get("callback")
  async callback(@Req() req: Request, @Res() res: Response) {
    const state = typeof req.query.state === "string" ? req.query.state : "";
    const name = state ? flowCookie(state) : "";
    const query = req.originalUrl.slice(req.originalUrl.indexOf("?"));
    const result = await this.auth.finish(query.startsWith("?") ? query : "", name ? req.cookies?.[name] : undefined, req.header("user-agent") ?? "");
    if (name) res.clearCookie(name, base());
    if (result.session) {
      const maxAge = cfg().SESSION_MAX_HOURS * 3600_000;
      res.cookie(sessionCookieName(), result.session.id, { ...base(), httpOnly: true, sameSite: "lax", maxAge });
      // Readable by the frontend (double-submit): sent back as X-CSRF-Token on every change.
      res.cookie(csrfCookieName(), result.session.csrf, { ...base(), httpOnly: false, sameSite: "strict", maxAge });
    }
    res.redirect(302, result.redirect);
  }

  /**
   * POST /bff/auth/logout (session + CSRF) -> { logout_url }: the BFF and Keycloak sessions end; the frontend then navigates to
   * logout_url (Keycloak's end-session page, which returns to /login). POST + CSRF so another site cannot sign people out.
   */
  @Post("logout")
  @HttpCode(200)
  @UseGuards(SessionGuard, CsrfGuard)
  async logout(@Req() req: SessionRequest, @Res() res: Response) {
    const logoutUrl = await this.auth.logout(req.bffSession?.rowId);
    res.clearCookie(sessionCookieName(), base());
    res.clearCookie(csrfCookieName(), base());
    res.json({ logout_url: logoutUrl });
  }
}

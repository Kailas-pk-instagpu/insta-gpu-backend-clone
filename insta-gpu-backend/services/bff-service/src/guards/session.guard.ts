import { CanActivate, ExecutionContext, Injectable } from "@nestjs/common";
import { ApiError } from "@instagpu/shared-http";
import type { Request } from "express";
import { sessionCookieName } from "../config";
import { SessionService, type BffSession } from "../modules/session/session.service";

export type SessionRequest = Request & { bffSession?: BffSession; accessToken?: string };

/**
 * A valid BFF session cookie (not revoked, not expired, not idle) and a usable access token, refreshed when close to expiry.
 * Sets req.bffSession and req.accessToken. Anything else: 401, and the frontend sends the person to the login page.
 */
@Injectable()
export class SessionGuard implements CanActivate {
  constructor(private readonly sessions: SessionService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<SessionRequest>();
    const session = await this.sessions.get(req.cookies?.[sessionCookieName()]);
    if (!session) throw new ApiError("UNAUTHENTICATED", "Your session has ended. Please sign in again.");
    const token = await this.sessions.accessToken(session.rowId);
    if (!token) throw new ApiError("UNAUTHENTICATED", "Your session has ended. Please sign in again.");
    req.bffSession = session;
    req.accessToken = token;
    return true;
  }
}

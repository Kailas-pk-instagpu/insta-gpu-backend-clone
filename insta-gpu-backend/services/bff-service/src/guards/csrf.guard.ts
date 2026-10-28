import { CanActivate, ExecutionContext, Injectable } from "@nestjs/common";
import { ApiError } from "@instagpu/shared-http";
import { SessionService } from "../modules/session/session.service";
import type { SessionRequest } from "./session.guard";

const SAFE = new Set(["GET", "HEAD", "OPTIONS"]);

/**
 * Double-submit CSRF check on every change: the X-CSRF-Token header (the frontend copies it from the readable igpu_csrf cookie) must
 * match the token stored (hashed) with this session. Use after SessionGuard. A cross-site page can send the cookie but cannot read it.
 */
@Injectable()
export class CsrfGuard implements CanActivate {
  constructor(private readonly sessions: SessionService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<SessionRequest>();
    if (SAFE.has(req.method)) return true;
    const ok = req.bffSession && (await this.sessions.checkCsrf(req.bffSession.rowId, req.header("x-csrf-token")));
    if (!ok) throw new ApiError("FORBIDDEN", "Security check failed. Refresh the page and try again.", { reason: "CSRF_FAILED" });
    return true;
  }
}

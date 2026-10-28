import { All, Controller, Req, Res, UseGuards } from "@nestjs/common";
import type { Response } from "express";
import { CsrfGuard } from "../../guards/csrf.guard";
import { SessionGuard, type SessionRequest } from "../../guards/session.guard";
import { ProxyService } from "./proxy.service";

/** ALL /bff/api/* -> KONG_URL/api/* (session, fresh access token, CSRF on changes). */
@Controller("bff/api")
@UseGuards(SessionGuard, CsrfGuard)
export class ProxyController {
  constructor(private readonly proxy: ProxyService) {}

  @All("*path")
  async forward(@Req() req: SessionRequest, @Res() res: Response) {
    const pathname = req.path.replace(/^\/bff\/api\//, "");
    const q = req.originalUrl.indexOf("?");
    const result = await this.proxy.forward({
      method: req.method,
      path: pathname,
      search: q >= 0 ? req.originalUrl.slice(q) : "",
      headers: req.headers,
      body: Buffer.isBuffer(req.body) ? req.body : undefined,
      sessionRowId: req.bffSession!.rowId,
      accessToken: req.accessToken!,
    });
    res.status(result.status).set(result.headers).send(result.body);
  }
}

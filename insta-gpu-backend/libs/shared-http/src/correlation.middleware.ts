import { randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Kong's correlation-id plugin (and the BFF) set X-Correlation-ID; we accept it if it is a UUID, otherwise mint one.
 * Ported from the reference. Register with app.use(correlationMiddleware) before the routes.
 */
export function correlationMiddleware(req: Request & { requestId?: string; correlationId?: string }, res: Response, next: NextFunction) {
  const incoming = req.header("x-correlation-id");
  req.correlationId = incoming && UUID.test(incoming) ? incoming : randomUUID();
  req.requestId = randomUUID();
  res.setHeader("X-Correlation-ID", req.correlationId);
  res.setHeader("X-Request-ID", req.requestId);
  next();
}

import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from "@nestjs/common";
import type { Request, Response } from "express";
import { log } from "./log";

/** Stable API error codes (ported from InstaGPU-GC-Core packages/domain/src/errors.ts; business-specific codes are added with their features). */
export const ERROR_CODES = {
  VALIDATION_FAILED: 400,
  UNAUTHENTICATED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  IDEMPOTENCY_CONFLICT: 409,
  RATE_LIMITED: 429,
  INTERNAL: 500,
  NOT_READY: 503,
} as const;
export type ErrorCode = keyof typeof ERROR_CODES;

/** Throw this from services. The filter turns it into the standard envelope. */
export class ApiError extends Error {
  constructor(readonly code: ErrorCode, message: string, readonly details: Record<string, unknown> = {}) {
    super(message);
  }
  get status(): number {
    return ERROR_CODES[this.code];
  }
}

/** Envelope: { code, message, request_id, correlation_id, details } — same for every error. */
@Catch()
export class ErrorEnvelopeFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    const req = host.switchToHttp().getRequest<Request & { requestId?: string; correlationId?: string }>();
    let status = 500;
    let code: string = "INTERNAL";
    let message = "Something went wrong. Quote the request id when contacting support.";
    let details: Record<string, unknown> = {};

    if (exception instanceof ApiError) {
      status = exception.status; code = exception.code; message = exception.message; details = exception.details;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = status === 401 ? "UNAUTHENTICATED" : status === 403 ? "FORBIDDEN" : status === 404 ? "NOT_FOUND" : status === 400 ? "VALIDATION_FAILED" : status === 503 ? "NOT_READY" : "INTERNAL";
      message = exception.message;
      const body = exception.getResponse();
      if (status === 503 && typeof body === "object") details = body as Record<string, unknown>; // /readyz checks
    } else {
      log("error", "unhandled error", { err: String((exception as Error)?.stack ?? exception), request_id: req.requestId, correlation_id: req.correlationId });
    }
    res.status(status).json({ code, message, request_id: req.requestId, correlation_id: req.correlationId, details });
  }
}

import { createParamDecorator, ExecutionContext } from "@nestjs/common";
import type { Principal } from "./principal";

/** The authenticated caller, set by JwtAuthGuard. */
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): Principal => ctx.switchToHttp().getRequest().principal);
export const CorrelationId = createParamDecorator((_: unknown, ctx: ExecutionContext): string => ctx.switchToHttp().getRequest().correlationId);
export const IdempotencyKey = createParamDecorator((_: unknown, ctx: ExecutionContext): string | undefined => ctx.switchToHttp().getRequest().header("idempotency-key"));

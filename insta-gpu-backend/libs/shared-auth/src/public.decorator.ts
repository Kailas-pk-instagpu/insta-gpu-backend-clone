import { SetMetadata } from "@nestjs/common";
import { PUBLIC_KEY } from "@instagpu/shared-http";

export { PUBLIC_KEY };
/** Opt a handler or controller out of the global JwtAuthGuard (health checks only). Everything else is denied without a valid token. */
export const Public = () => SetMetadata(PUBLIC_KEY, true);

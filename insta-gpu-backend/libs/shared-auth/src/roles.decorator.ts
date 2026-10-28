import { SetMetadata } from "@nestjs/common";
import type { Role } from "./principal";

export const ROLES_KEY = "instagpu:roles";
/** Allow-list of realm roles for a handler (the lowest role allowed; inheritance is applied). Combine with scope checks in the service. */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);

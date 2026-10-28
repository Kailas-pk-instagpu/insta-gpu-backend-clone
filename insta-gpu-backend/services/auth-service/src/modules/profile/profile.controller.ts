import { Controller, Get } from "@nestjs/common";
import { CurrentUser, type Principal } from "@instagpu/shared-auth";
import { ProfileService } from "./profile.service";

@Controller("me")
export class ProfileController {
  constructor(private readonly profile: ProfileService) {}

  /** GET /api/v1/me — who is signed in: role, effective roles, memberships, profile. The BFF calls it at login; the frontend on load. */
  @Get()
  me(@CurrentUser() p: Principal) {
    return this.profile.me(p);
  }
}

import { Module } from "@nestjs/common";
import { HealthModule } from "@instagpu/shared-http";
import { DbModule, pingDb } from "@instagpu/shared-db";
import { AuthModule } from "@instagpu/shared-auth";
import { UsersService } from "./modules/users/users.service";
import { UsersModule } from "./modules/users/users.module";
import { MembershipsModule } from "./modules/memberships/memberships.module";
import { ProfileModule } from "./modules/profile/profile.module";
import { KeycloakModule } from "./modules/keycloak/keycloak.module";
import { InternalModule } from "./internal/internal.module";

@Module({
  imports: [
    HealthModule.forService({ name: "auth-service", version: "0.1.0", readiness: { database: () => pingDb() } }),
    DbModule.forService("auth-service"),
    // Global JwtAuthGuard (deny by default). auth-service resolves people from its own tables (UsersService).
    AuthModule.forService("auth-service", { resolver: UsersService, imports: [UsersModule] }),
    UsersModule,
    MembershipsModule,
    ProfileModule,
    KeycloakModule,
    InternalModule,
  ],
})
export class AppModule {}

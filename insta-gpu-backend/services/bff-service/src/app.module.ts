import { Module } from "@nestjs/common";
import { HealthModule } from "@instagpu/shared-http";
import { DbModule, pingDb } from "@instagpu/shared-db";
import { AuthModule } from "./modules/auth/auth.module";
import { SessionModule } from "./modules/session/session.module";
import { ProxyModule } from "./modules/proxy/proxy.module";

@Module({
  imports: [
    HealthModule.forService({ name: "bff-service", version: "0.1.0", readiness: { database: () => pingDb() } }),
    DbModule.forService("bff-service"),
    AuthModule,
    SessionModule,
    ProxyModule,
  ],
})
export class AppModule {}

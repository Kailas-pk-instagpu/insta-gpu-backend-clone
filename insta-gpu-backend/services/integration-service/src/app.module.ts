import { Module } from "@nestjs/common";
import { HealthModule } from "@instagpu/shared-http";
import { DbModule, pingDb } from "@instagpu/shared-db";
import { HorizonModule } from "./modules/horizon/horizon.module";
import { ClientsModule } from "./clients/clients.module";
import { JobsModule } from "./jobs/jobs.module";
import { InternalModule } from "./internal/internal.module";

@Module({
  imports: [
    HealthModule.forService({ name: "integration-service", version: "0.1.0", readiness: { database: () => pingDb() } }),
    DbModule.forService("integration-service"),
    HorizonModule,
    ClientsModule,
    JobsModule,
    InternalModule,
  ],
})
export class AppModule {}

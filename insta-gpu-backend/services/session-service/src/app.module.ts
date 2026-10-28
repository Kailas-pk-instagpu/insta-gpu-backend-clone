import { Module } from "@nestjs/common";
import { HealthModule } from "@instagpu/shared-http";
import { DbModule, pingDb } from "@instagpu/shared-db";
import { SessionsModule } from "./modules/sessions/sessions.module";
import { FloorModule } from "./modules/floor/floor.module";
import { DashboardModule } from "./modules/dashboard/dashboard.module";
import { CapacityModule } from "./modules/capacity/capacity.module";
import { AccountStandingModule } from "./modules/account-standing/account-standing.module";
import { AgentsModule } from "./modules/agents/agents.module";
import { ClientsModule } from "./clients/clients.module";
import { JobsModule } from "./jobs/jobs.module";
import { InternalModule } from "./internal/internal.module";

@Module({
  imports: [
    HealthModule.forService({ name: "session-service", version: "0.1.0", readiness: { database: () => pingDb() } }),
    DbModule.forService("session-service"),
    SessionsModule,
    FloorModule,
    DashboardModule,
    CapacityModule,
    AccountStandingModule,
    AgentsModule,
    ClientsModule,
    JobsModule,
    InternalModule,
  ],
})
export class AppModule {}

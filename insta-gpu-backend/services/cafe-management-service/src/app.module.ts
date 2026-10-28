import { Module } from "@nestjs/common";
import { HealthModule } from "@instagpu/shared-http";
import { DbModule, pingDb } from "@instagpu/shared-db";
import { OwnersModule } from "./modules/owners/owners.module";
import { BranchesModule } from "./modules/branches/branches.module";
import { ApprovalsModule } from "./modules/approvals/approvals.module";
import { SeatsModule } from "./modules/seats/seats.module";
import { IssuesModule } from "./modules/issues/issues.module";
import { ClientsModule } from "./clients/clients.module";
import { InternalModule } from "./internal/internal.module";

@Module({
  imports: [
    HealthModule.forService({ name: "cafe-management-service", version: "0.1.0", readiness: { database: () => pingDb() } }),
    DbModule.forService("cafe-management-service"),
    OwnersModule,
    BranchesModule,
    ApprovalsModule,
    SeatsModule,
    IssuesModule,
    ClientsModule,
    InternalModule,
  ],
})
export class AppModule {}

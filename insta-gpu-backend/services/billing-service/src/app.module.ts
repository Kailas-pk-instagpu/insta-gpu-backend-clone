import { Module } from "@nestjs/common";
import { HealthModule } from "@instagpu/shared-http";
import { DbModule, pingDb } from "@instagpu/shared-db";
import { BillingModule } from "./modules/billing/billing.module";
import { PaymentsModule } from "./modules/payments/payments.module";
import { NotificationsModule } from "./modules/notifications/notifications.module";
import { ClientsModule } from "./clients/clients.module";
import { JobsModule } from "./jobs/jobs.module";
import { InternalModule } from "./internal/internal.module";

@Module({
  imports: [
    HealthModule.forService({ name: "billing-service", version: "0.1.0", readiness: { database: () => pingDb() } }),
    DbModule.forService("billing-service"),
    BillingModule,
    PaymentsModule,
    NotificationsModule,
    ClientsModule,
    JobsModule,
    InternalModule,
  ],
})
export class AppModule {}

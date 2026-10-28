import { Module } from "@nestjs/common";
import { BillingClient } from "./billing.client";
import { CafeClient } from "./cafe.client";
import { IntegrationClient } from "./integration.client";

@Module({
  providers: [BillingClient, CafeClient, IntegrationClient],
  exports: [BillingClient, CafeClient, IntegrationClient],
})
export class ClientsModule {}

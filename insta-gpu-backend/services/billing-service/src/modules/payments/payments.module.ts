import { Module } from "@nestjs/common";
import { HitPayProvider } from "./hitpay.provider";
import { PaymentsController } from "./payments.controller";
import { PaymentsRepository } from "./payments.repository";
import { PaymentsService } from "./payments.service";
import { WebhookController } from "./webhook.controller";

@Module({
  controllers: [PaymentsController, WebhookController],
  providers: [PaymentsService, PaymentsRepository, HitPayProvider],
  exports: [PaymentsService],
})
export class PaymentsModule {}

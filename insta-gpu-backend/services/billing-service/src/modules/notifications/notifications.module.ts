import { Module } from "@nestjs/common";
import { Mailer } from "./mailer";
import { NotificationsService } from "./notifications.service";

@Module({
  providers: [Mailer, NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}

import { Module } from "@nestjs/common";
import { AccountStandingRepository } from "./account-standing.repository";
import { AccountStandingService } from "./account-standing.service";

@Module({
  providers: [AccountStandingService, AccountStandingRepository],
  exports: [AccountStandingService],
})
export class AccountStandingModule {}

import { Module } from "@nestjs/common";
import { MembershipsController } from "./memberships.controller";
import { MembershipsRepository } from "./memberships.repository";
import { MembershipsService } from "./memberships.service";

@Module({
  controllers: [MembershipsController],
  providers: [MembershipsService, MembershipsRepository],
  exports: [MembershipsService],
})
export class MembershipsModule {}

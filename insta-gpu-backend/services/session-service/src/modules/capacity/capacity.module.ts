import { Module } from "@nestjs/common";
import { CapacityController } from "./capacity.controller";
import { CapacityRepository } from "./capacity.repository";
import { CapacityService } from "./capacity.service";

@Module({
  controllers: [CapacityController],
  providers: [CapacityService, CapacityRepository],
  exports: [CapacityService],
})
export class CapacityModule {}

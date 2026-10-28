import { Module } from "@nestjs/common";
import { FloorController } from "./floor.controller";
import { FloorRepository } from "./floor.repository";
import { FloorService } from "./floor.service";

@Module({
  controllers: [FloorController],
  providers: [FloorService, FloorRepository],
  exports: [FloorService],
})
export class FloorModule {}

import { Module } from "@nestjs/common";
import { SeatsController } from "./seats.controller";
import { SeatsRepository } from "./seats.repository";
import { SeatsService } from "./seats.service";

@Module({
  controllers: [SeatsController],
  providers: [SeatsService, SeatsRepository],
  exports: [SeatsService],
})
export class SeatsModule {}

import { Module } from "@nestjs/common";
import { HorizonClient } from "./horizon-client";
import { HorizonController } from "./horizon.controller";
import { HorizonRepository } from "./horizon.repository";
import { HorizonService } from "./horizon.service";
import { SnapshotService } from "./snapshot.service";

@Module({
  controllers: [HorizonController],
  providers: [HorizonService, HorizonRepository, HorizonClient, SnapshotService],
  exports: [HorizonService],
})
export class HorizonModule {}

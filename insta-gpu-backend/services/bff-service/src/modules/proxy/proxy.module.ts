import { Module } from "@nestjs/common";
import { ProxyController } from "./proxy.controller";
import { ProxyRepository } from "./proxy.repository";
import { ProxyService } from "./proxy.service";

@Module({
  controllers: [ProxyController],
  providers: [ProxyService, ProxyRepository],
  exports: [ProxyService],
})
export class ProxyModule {}

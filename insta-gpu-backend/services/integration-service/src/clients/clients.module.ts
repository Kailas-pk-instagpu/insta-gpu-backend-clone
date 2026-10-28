import { Module } from "@nestjs/common";
import { SessionClient } from "./session.client";

@Module({
  providers: [SessionClient],
  exports: [SessionClient],
})
export class ClientsModule {}

import { Module } from "@nestjs/common";
import { CafeClient } from "./cafe.client";
import { SessionClient } from "./session.client";

@Module({
  providers: [SessionClient, CafeClient],
  exports: [SessionClient, CafeClient],
})
export class ClientsModule {}

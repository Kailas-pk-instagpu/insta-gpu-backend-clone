import { Module } from "@nestjs/common";
import { AuthClient } from "./auth.client";

@Module({
  providers: [AuthClient],
  exports: [AuthClient],
})
export class ClientsModule {}

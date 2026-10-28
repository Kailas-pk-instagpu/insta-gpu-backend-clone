import { Module } from "@nestjs/common";
import { IssuesController } from "./issues.controller";
import { IssuesRepository } from "./issues.repository";
import { IssuesService } from "./issues.service";

@Module({
  controllers: [IssuesController],
  providers: [IssuesService, IssuesRepository],
  exports: [IssuesService],
})
export class IssuesModule {}

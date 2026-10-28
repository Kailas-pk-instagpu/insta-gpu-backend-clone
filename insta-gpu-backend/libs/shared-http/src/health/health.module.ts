import { DynamicModule, Module } from "@nestjs/common";
import { HealthController } from "./health.controller";
import { SERVICE_INFO, type ServiceInfo } from "./health.constants";

@Module({})
export class HealthModule {
  /** Register in a service's AppModule: HealthModule.forService({ name: "session-service", version: "0.1.0" }) */
  static forService(info: ServiceInfo): DynamicModule {
    return {
      module: HealthModule,
      controllers: [HealthController],
      providers: [{ provide: SERVICE_INFO, useValue: info }],
    };
  }
}

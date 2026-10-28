import "reflect-metadata";
import { Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // Business routes live under /api/v1; health checks stay at the root for probes.
  app.setGlobalPrefix("api/v1", { exclude: ["healthz", "readyz"] });
  app.enableShutdownHooks(); // finish in-flight work on SIGTERM
  const port = Number(process.env.PORT ?? process.env.BILLING_PORT ?? 3004);
  await app.listen(port);
  Logger.log(`billing-service listening on port ${port}`, "Bootstrap");
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});

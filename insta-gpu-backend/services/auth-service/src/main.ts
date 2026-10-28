import "reflect-metadata";
import { Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { correlationMiddleware, ErrorEnvelopeFilter } from "@instagpu/shared-http";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  // Business routes live under /api/v1; health checks stay at the root for probes.
  app.setGlobalPrefix("api/v1", { exclude: ["healthz", "readyz"] });
  app.use(correlationMiddleware);
  app.useGlobalFilters(new ErrorEnvelopeFilter());
  app.set("trust proxy", 1); // Kong
  app.enableShutdownHooks(); // finish in-flight work on SIGTERM
  const port = Number(process.env.PORT ?? process.env.AUTH_PORT ?? 3001);
  await app.listen(port);
  Logger.log(`auth-service listening on port ${port}`, "Bootstrap");
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});

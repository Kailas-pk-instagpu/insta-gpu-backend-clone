import "reflect-metadata";
import { Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import type { NestExpressApplication } from "@nestjs/platform-express";
import cookieParser from "cookie-parser";
import express from "express";
import { correlationMiddleware, ErrorEnvelopeFilter } from "@instagpu/shared-http";
import { AppModule } from "./app.module";
import { cfg } from "./config";

async function bootstrap() {
  cfg(); // validate configuration before anything listens (fail fast)
  // The proxy forwards bodies untouched: read them raw (max 1 MB, like Kong), never parse JSON here.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bodyParser: false });
  app.use("/bff/api", express.raw({ type: () => true, limit: "1mb" }));
  app.use(cookieParser());
  app.use(correlationMiddleware);
  app.useGlobalFilters(new ErrorEnvelopeFilter());
  app.disable("x-powered-by");
  app.set("trust proxy", 1); // the frontend's dev server (or the edge proxy) in front
  app.enableShutdownHooks(); // finish in-flight work on SIGTERM
  // Routes: /bff/auth/* (login, callback, logout), /bff/api/* (proxy to Kong), /healthz, /readyz. No global prefix.
  const port = Number(process.env.PORT ?? process.env.BFF_PORT ?? 3000);
  await app.listen(port);
  Logger.log(`bff-service listening on port ${port}`, "Bootstrap");
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});

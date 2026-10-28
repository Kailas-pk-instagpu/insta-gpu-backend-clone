// Runs the database tests against the local stack (docker compose up first). Usage: pnpm test:db
// Defaults are the DEV-ONLY compose values (.env.example); override with TEST_ADMIN_DATABASE_URL / TEST_APP_DATABASE_URL.
import { spawnSync } from "node:child_process";

const port = process.env.POSTGRES_PORT ?? "5433";
const env = {
  ...process.env,
  TEST_ADMIN_DATABASE_URL: process.env.TEST_ADMIN_DATABASE_URL ?? `postgres://postgres:${process.env.POSTGRES_PASSWORD ?? "postgres"}@localhost:${port}/instagpu`,
  TEST_APP_DATABASE_URL: process.env.TEST_APP_DATABASE_URL ?? `postgres://app_cafe_login:${process.env.APP_CAFE_DB_PASSWORD ?? "app_cafe_dev"}@localhost:${port}/instagpu`,
};
const r = spawnSync("pnpm", ["--filter", "@instagpu/shared-db", "test"], { env, stdio: "inherit", shell: true });
process.exitCode = r.status ?? 1;

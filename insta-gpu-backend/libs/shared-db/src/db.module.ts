import { DynamicModule, Global, Inject, Injectable, Module, OnApplicationShutdown } from "@nestjs/common";
import type pg from "pg";
import { closeDb, getDb } from "./tx";

export const DB_POOL = Symbol("DB_POOL");

@Injectable()
class DbLifecycle implements OnApplicationShutdown {
  constructor(@Inject(DB_POOL) readonly pool: pg.Pool) {}
  async onApplicationShutdown() {
    await closeDb();
  }
}

/**
 * Register once in a service's AppModule: DbModule.forService("auth-service").
 * Fails at startup when DATABASE_URL is missing; the pool connects lazily, and /readyz reports whether PostgreSQL answers.
 * Repositories use withTx() / getDb() directly (as in the reference); DB_POOL is there for injection where preferred.
 */
@Global()
@Module({})
export class DbModule {
  static forService(serviceName: string): DynamicModule {
    return {
      module: DbModule,
      providers: [
        {
          provide: DB_POOL,
          useFactory: () => {
            process.env.SERVICE_NAME ??= serviceName;
            return getDb();
          },
        },
        DbLifecycle,
      ],
      exports: [DB_POOL],
    };
  }
}

import pg from "pg";

// Ported from InstaGPU-GC-Core apps/platform/src/shared/db.ts.

export type Db = pg.Pool;
export type Tx = pg.PoolClient;

export interface TenantContext {
  /** Tenant the caller is acting in. Required for cafe roles. */
  tenantId?: string;
  /** Only for platform staff (super_admin / admin) after the role check: lets RLS show all tenants. */
  platformScope?: boolean;
  correlationId?: string;
}

let pool: pg.Pool | undefined;

/** The service's pool. Each service connects with its own login (app_<service>_login), never the migrator. */
export function getDb(url = process.env.DATABASE_URL): pg.Pool {
  if (!pool) {
    if (!url) throw new Error("DATABASE_URL is not set");
    pool = new pg.Pool({
      connectionString: url,
      max: Number(process.env.DB_POOL_MAX ?? 10),
      application_name: `instagpu-${process.env.SERVICE_NAME ?? "service"}`,
    });
    // An idle connection dropped by the server (restart, failover) is an 'error' event on the pool; unhandled, it kills
    // the process. Log it: the pool discards that client and opens a new one on the next query; /readyz shows the outage.
    pool.on("error", (err) => {
      process.stderr.write(JSON.stringify({ ts: new Date().toISOString(), level: "warn", msg: "idle database connection lost", err: err.message }) + "\n");
    });
  }
  return pool;
}

/** Close the pool (shutdown hook). Safe to call twice. */
export async function closeDb() {
  const p = pool;
  pool = undefined;
  if (p) await p.end();
}

/**
 * Every request that touches tenant data runs inside ONE transaction with the tenant set via
 * SET LOCAL, so PostgreSQL RLS applies even if a query forgets a WHERE tenant_id = ... clause.
 */
export async function withTx<T>(ctx: TenantContext, fn: (tx: Tx) => Promise<T>, db: pg.Pool = getDb()): Promise<T> {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.tenant_id', $1, true), set_config('app.platform_scope', $2, true), set_config('app.correlation_id', $3, true)", [
      ctx.tenantId ?? "",
      ctx.platformScope ? "on" : "off",
      ctx.correlationId ?? "",
    ]);
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK").catch(() => undefined);
    throw err;
  } finally {
    client.release();
  }
}

/** Readiness probe: one round trip to PostgreSQL, bounded by a timeout. */
export async function pingDb(timeoutMs = 2000, db: pg.Pool = getDb()): Promise<void> {
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      db.query("SELECT 1"),
      new Promise((_, reject) => (timer = setTimeout(() => reject(new Error(`database did not answer within ${timeoutMs} ms`)), timeoutMs))),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

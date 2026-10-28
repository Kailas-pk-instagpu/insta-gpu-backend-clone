import type pg from "pg";
import { getDb } from "./tx";

/** Cluster-wide leader lock for scheduled jobs (several copies of a service may run; only one runs a job). */
export async function withAdvisoryLock<T>(lockName: string, fn: () => Promise<T>, db: pg.Pool = getDb()): Promise<{ ran: boolean; result?: T }> {
  const client = await db.connect();
  try {
    const { rows } = await client.query<{ ok: boolean }>("SELECT pg_try_advisory_lock(hashtext($1)) AS ok", [lockName]);
    if (!rows[0]?.ok) return { ran: false };
    try {
      return { ran: true, result: await fn() };
    } finally {
      await client.query("SELECT pg_advisory_unlock(hashtext($1))", [lockName]);
    }
  } finally {
    client.release();
  }
}

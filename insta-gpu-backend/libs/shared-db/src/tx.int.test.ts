import pg from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { withAdvisoryLock } from "./advisory-lock";
import { pingDb, withTx } from "./tx";

/**
 * Runs against the local stack (docker compose) when both URLs are set, e.g.
 *   TEST_ADMIN_DATABASE_URL=postgres://postgres:postgres@localhost:5433/instagpu
 *   TEST_APP_DATABASE_URL=postgres://app_cafe_login:app_cafe_dev@localhost:5433/instagpu
 * The admin (migrator) connection seeds two cafes; the app connection is a service login, so RLS applies.
 */
const adminUrl = process.env.TEST_ADMIN_DATABASE_URL;
const appUrl = process.env.TEST_APP_DATABASE_URL;

const A = "a0000000-0000-4000-8000-00000000000a";
const B = "b0000000-0000-4000-8000-00000000000b";

describe.skipIf(!adminUrl || !appUrl)("withTx against PostgreSQL (RLS through a service login)", () => {
  let admin: pg.Pool;
  let app: pg.Pool;

  beforeAll(async () => {
    admin = new pg.Pool({ connectionString: adminUrl });
    app = new pg.Pool({ connectionString: appUrl });
    await admin.query(`DELETE FROM core.tenants WHERE id IN ($1, $2)`, [A, B]);
    await admin.query(`INSERT INTO core.tenants(id, code, name, legal_name) VALUES ($1,'TEST-A','A','A Sdn Bhd'), ($2,'TEST-B','B','B Sdn Bhd')`, [A, B]);
  });

  afterAll(async () => {
    await admin?.query(`DELETE FROM core.tenants WHERE id IN ($1, $2)`, [A, B]);
    await Promise.all([admin?.end(), app?.end()]);
  });

  const visible = (ctx: Parameters<typeof withTx>[0]) =>
    withTx(ctx, async (tx) => (await tx.query(`SELECT id FROM core.tenants WHERE id IN ($1, $2) ORDER BY id`, [A, B])).rows.map((r) => r.id), app);

  it("answers the readiness ping", async () => {
    await expect(pingDb(2000, app)).resolves.toBeUndefined();
  });

  it("sees no rows without a tenant, one cafe with app.tenant_id, every cafe with platform scope", async () => {
    expect(await visible({})).toEqual([]);
    expect(await visible({ tenantId: A })).toEqual([A]);
    expect(await visible({ platformScope: true })).toEqual([A, B]);
  });

  it("refuses a write into another cafe", async () => {
    const write = withTx({ tenantId: A }, (tx) => tx.query(`INSERT INTO core.branches(tenant_id, code, name) VALUES ($1, 'X', 'X')`, [B]), app);
    await expect(write).rejects.toThrow(/row-level security/);
  });

  it("scope is per transaction (SET LOCAL): the next transaction on the same pool starts empty", async () => {
    expect(await visible({ tenantId: A })).toEqual([A]);
    expect(await visible({})).toEqual([]);
  });

  it("rolls back when the callback throws", async () => {
    await expect(
      withTx({ tenantId: A }, async (tx) => {
        await tx.query(`UPDATE core.tenants SET name = 'changed' WHERE id = $1`, [A]);
        throw new Error("boom");
      }, app),
    ).rejects.toThrow("boom");
    const { rows } = await admin.query(`SELECT name FROM core.tenants WHERE id = $1`, [A]);
    expect(rows[0].name).toBe("A");
  });

  it("advisory lock: a second holder does not run while the first holds it", async () => {
    let inner: { ran: boolean } | undefined;
    const outer = await withAdvisoryLock("test-lock", async () => {
      inner = await withAdvisoryLock("test-lock", async () => "second", app);
      return "first";
    }, app);
    expect(outer).toEqual({ ran: true, result: "first" });
    expect(inner).toEqual({ ran: false });
  });
});

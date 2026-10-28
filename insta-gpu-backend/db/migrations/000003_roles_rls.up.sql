-- 000003 Runtime roles + row-level security (defence in depth; the API still checks scope first).
-- Group roles are NOLOGIN. Login users (app_api_login, ...) are created by OPS with passwords from
-- OpenBao and GRANTed one group role each. Migrations run as the owner role (migrator), which owns the
-- tables and therefore bypasses RLS: never use the migrator credentials in an application.
BEGIN;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_api') THEN CREATE ROLE app_api NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_worker') THEN CREATE ROLE app_worker NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_adapter') THEN CREATE ROLE app_adapter NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_bff') THEN CREATE ROLE app_bff NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') THEN CREATE ROLE app_readonly NOLOGIN; END IF;
END $$;

GRANT USAGE ON SCHEMA identity, core, gaming, commercial, billing, payments, ledger, integration, audit
  TO app_api, app_worker, app_adapter, app_readonly;
GRANT USAGE ON SCHEMA identity TO app_bff;

-- api + worker: read/write business tables
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA identity, core, gaming, commercial, billing, payments, integration
  TO app_api, app_worker;
GRANT DELETE ON integration.idempotency_keys TO app_api, app_worker;
GRANT DELETE ON identity.bff_sessions TO app_worker;
-- ledger + audit: INSERT and SELECT only (the triggers also forbid UPDATE/DELETE)
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA ledger, audit TO app_api, app_worker;
GRANT UPDATE (status) ON ledger.journal_entries TO app_worker;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ledger, gaming TO app_api, app_worker;

-- infra-adapter: only what Horizon sync needs
GRANT SELECT ON core.seats, core.machines, core.branches, core.seat_machine_assignments, gaming.sessions TO app_adapter;
GRANT SELECT, INSERT, UPDATE ON integration.external_refs, gaming.horizon_sessions TO app_adapter;
GRANT SELECT, INSERT ON gaming.horizon_observations, integration.domain_events, integration.outbox_events, audit.events TO app_adapter;
GRANT UPDATE (status, metadata, updated_at) ON core.machines TO app_adapter;
GRANT USAGE ON SEQUENCE gaming.horizon_observations_id_seq TO app_adapter;

-- BFF: only its own session store
GRANT SELECT, INSERT, UPDATE ON identity.bff_sessions TO app_bff;
GRANT SELECT ON identity.users TO app_bff;

-- reporting / support (read-only)
GRANT SELECT ON ALL TABLES IN SCHEMA identity, core, gaming, commercial, billing, payments, ledger, integration, audit TO app_readonly;
REVOKE SELECT ON identity.bff_sessions, integration.idempotency_keys FROM app_readonly;

-- RLS: app_api sees only rows of app.tenant_id (SET LOCAL per transaction).
-- app_worker runs cross-tenant jobs (billing run, hold job) and gets an explicit all-rows policy.
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT * FROM (VALUES
    ('core','branches','tenant_id'),
    ('gaming','sessions','tenant_id'),
    ('commercial','usage_records','tenant_id'),
    ('commercial','commercial_accounts','tenant_id'),
    ('billing','charges','tenant_id'),
    ('billing','invoices','tenant_id'),
    ('audit','events','tenant_id'),
    ('integration','device_identities','tenant_id')
  ) AS x(s, n, col) LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', t.s, t.n);
    EXECUTE format('CREATE POLICY p_tenant_api ON %I.%I TO app_api USING (%I::text = current_setting(''app.tenant_id'', true)) WITH CHECK (%I::text = current_setting(''app.tenant_id'', true))', t.s, t.n, t.col, t.col);
    EXECUTE format('CREATE POLICY p_worker_all ON %I.%I TO app_worker USING (true) WITH CHECK (true)', t.s, t.n);
    EXECUTE format('CREATE POLICY p_readonly_all ON %I.%I FOR SELECT TO app_readonly USING (true)', t.s, t.n);
  END LOOP;
END $$;

-- Platform staff (platform_admin / finance_admin) act across tenants through the API with
-- app.tenant_id = '*' and app.platform_scope = 'on'; the API sets these only after the role check.
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT * FROM (VALUES ('core','branches'),('gaming','sessions'),('commercial','usage_records'),
    ('commercial','commercial_accounts'),('billing','charges'),('billing','invoices'),('audit','events'),
    ('integration','device_identities')) AS x(s, n) LOOP
    EXECUTE format('CREATE POLICY p_platform_api ON %I.%I TO app_api USING (current_setting(''app.platform_scope'', true) = ''on'') WITH CHECK (current_setting(''app.platform_scope'', true) = ''on'')', t.s, t.n);
  END LOOP;
END $$;

-- payment_orders via account
ALTER TABLE payments.payment_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api ON payments.payment_orders TO app_api
  USING (current_setting('app.platform_scope', true) = 'on' OR commercial_account_id IN (
    SELECT id FROM commercial.commercial_accounts WHERE tenant_id::text = current_setting('app.tenant_id', true)));
CREATE POLICY p_worker_all ON payments.payment_orders TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON payments.payment_orders FOR SELECT TO app_readonly USING (true);

COMMIT;

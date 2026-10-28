-- Per-service database roles. Runs AFTER db/migrations (compose service `db-roles`), as the migrator; safe to run again.
--
-- The reference (InstaGPU-GC-Core, migrations 000003/000006/...) has one API role, app_api, with tenant RLS policies:
--   p_tenant_api   : rows of app.tenant_id only (SET LOCAL by withTx)
--   p_platform_api : every row when app.platform_scope = 'on' (set only after the platform-staff role check)
-- Here each service gets its OWN NOLOGIN group role, granted only its own schemas, and the same RLS model: every
-- app_api policy on a table the service may touch is mirrored for that service's role (see the end of this file).
-- Migrations stay unchanged; new tables are picked up the next time this script runs (after every migrate).
--
-- Schema ownership (CLAUDE.md):
--   app_bff          identity.bff_sessions (+ read identity.users), exactly as the reference app_bff
--   app_auth         identity.*, core.tenant_memberships; reads core.tenants / core.branches to validate memberships
--   app_cafe         core.* except tenant_memberships
--   app_session      gaming.*
--   app_billing      billing.*, commercial.*, payments.*, ledger.* (ledger append-only, as the reference)
--   app_integration  integration.*
--   app_readonly     read everything except BFF sessions and idempotency keys (reference)
-- Every service except the BFF also writes audit.events and integration.idempotency_keys (shared infrastructure
-- tables ported as-is from the reference; rows are separated by tenant_id / idempotency scope).
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['app_bff','app_auth','app_cafe','app_session','app_billing','app_integration','app_readonly'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN EXECUTE format('CREATE ROLE %I NOLOGIN', r); END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------- bff-service
GRANT USAGE ON SCHEMA identity TO app_bff;
GRANT SELECT, INSERT, UPDATE ON identity.bff_sessions TO app_bff;
GRANT SELECT ON identity.users TO app_bff;

-- ---------------------------------------------------------------- auth-service
GRANT USAGE ON SCHEMA identity, core, audit, integration TO app_auth;
GRANT SELECT, INSERT, UPDATE ON identity.users TO app_auth;
GRANT SELECT, INSERT, UPDATE, DELETE ON identity.user_avatars TO app_auth;
GRANT SELECT, INSERT, UPDATE ON identity.notifications, identity.account_deletion_requests TO app_auth;
GRANT SELECT, INSERT, UPDATE ON core.tenant_memberships TO app_auth;
GRANT SELECT ON core.tenants, core.branches TO app_auth;
GRANT EXECUTE ON FUNCTION core.active_memberships_of(uuid) TO app_auth;

-- ---------------------------------------------------------------- cafe-management-service
GRANT USAGE ON SCHEMA core, audit, integration TO app_cafe;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO app_cafe;
REVOKE ALL ON core.tenant_memberships FROM app_cafe;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO app_cafe;

-- ---------------------------------------------------------------- session-service
GRANT USAGE ON SCHEMA gaming, audit, integration TO app_session;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA gaming TO app_session;
-- retention clean-up of agent data (reference: app_worker, 000019)
GRANT DELETE ON gaming.game_activity, gaming.agent_status, gaming.thin_client_events, gaming.thin_clients TO app_session;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA gaming TO app_session;

-- ---------------------------------------------------------------- billing-service
GRANT USAGE ON SCHEMA billing, commercial, payments, ledger, audit, integration TO app_billing;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA billing, commercial, payments TO app_billing;
-- ledger: INSERT and SELECT only (triggers also forbid UPDATE/DELETE); posting status as the reference worker
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA ledger TO app_billing;
GRANT UPDATE (status) ON ledger.journal_entries TO app_billing;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA billing, commercial, payments, ledger TO app_billing;

-- ---------------------------------------------------------------- integration-service
GRANT USAGE ON SCHEMA integration, audit TO app_integration;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA integration TO app_integration;
GRANT DELETE ON integration.horizon_unmatched, integration.horizon_login_check TO app_integration;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA integration TO app_integration;

-- ---------------------------------------------------------------- shared: audit + idempotency (all services but the BFF)
GRANT SELECT, INSERT ON audit.events TO app_auth, app_cafe, app_session, app_billing, app_integration;
GRANT SELECT, INSERT, UPDATE, DELETE ON integration.idempotency_keys TO app_auth, app_cafe, app_session, app_billing, app_integration;

-- ---------------------------------------------------------------- read-only (reporting / support), as the reference
GRANT USAGE ON SCHEMA identity, core, gaming, commercial, billing, payments, ledger, integration, audit TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA identity, core, gaming, commercial, billing, payments, ledger, integration, audit TO app_readonly;
REVOKE SELECT ON identity.bff_sessions, integration.idempotency_keys FROM app_readonly;

-- ---------------------------------------------------------------- RLS: mirror the reference's app_api policies
-- For every table with row-level security, each app_api policy (p_tenant_api, p_platform_api, p_read_all, ...) is copied as
-- "<policy>__<role>" for every service role that has a privilege on that table, with the same command, USING and WITH CHECK.
-- A table with RLS and no policy for a role returns no rows to it (deny by default). The BFF's table has no RLS (reference).
DO $$
DECLARE
  r text;
  p record;
BEGIN
  -- drop earlier copies so a changed reference policy is picked up
  FOR p IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE policyname LIKE '%\_\_app\_%' LOOP
    EXECUTE format('DROP POLICY %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
  END LOOP;

  FOREACH r IN ARRAY ARRAY['app_auth','app_cafe','app_session','app_billing','app_integration'] LOOP
    FOR p IN
      SELECT pol.schemaname, pol.tablename, pol.policyname, pol.permissive, pol.cmd, pol.qual, pol.with_check
      FROM pg_policies pol
      WHERE 'app_api' = ANY (pol.roles)
        AND has_table_privilege(r, format('%I.%I', pol.schemaname, pol.tablename), 'SELECT,INSERT,UPDATE,DELETE')
    LOOP
      EXECUTE format('CREATE POLICY %I ON %I.%I AS %s FOR %s TO %I%s%s',
        p.policyname || '__' || r, p.schemaname, p.tablename, p.permissive, p.cmd, r,
        CASE WHEN p.qual IS NOT NULL THEN format(' USING (%s)', p.qual) ELSE '' END,
        CASE WHEN p.with_check IS NOT NULL THEN format(' WITH CHECK (%s)', p.with_check) ELSE '' END);
    END LOOP;
  END LOOP;
END $$;

COMMIT;

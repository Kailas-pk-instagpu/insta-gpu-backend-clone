-- 000006 Row-level security on core.tenants, core.tenant_memberships and core.seats (closes the gap noted in STATUS).
-- Same model as 000003: app_api sees only its own tenant (app.tenant_id) or everything under platform scope; app_worker sees all (cross-tenant jobs);
-- app_adapter may READ seats (Horizon sync); app_readonly may read all. The migrator/owner role bypasses RLS as before.
-- Login has to find a user's memberships BEFORE any tenant is known: that single lookup is a SECURITY DEFINER function, not an open policy.
BEGIN;

CREATE OR REPLACE FUNCTION core.active_memberships_of(p_user uuid)
RETURNS TABLE (tenant_id uuid, role text, branch_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, core AS $$
  SELECT m.tenant_id, m.role, m.branch_id
  FROM core.tenant_memberships m JOIN core.tenants t ON t.id = m.tenant_id
  WHERE m.user_id = p_user AND m.status = 'ACTIVE' AND t.status IN ('ACTIVE','SUSPENDED')
$$;
REVOKE ALL ON FUNCTION core.active_memberships_of(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION core.active_memberships_of(uuid) TO app_api, app_worker;

ALTER TABLE core.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api    ON core.tenants TO app_api USING (id::text = current_setting('app.tenant_id', true)) WITH CHECK (id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api  ON core.tenants TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all    ON core.tenants TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all  ON core.tenants FOR SELECT TO app_readonly USING (true);

ALTER TABLE core.tenant_memberships ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api    ON core.tenant_memberships TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api  ON core.tenant_memberships TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all    ON core.tenant_memberships TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all  ON core.tenant_memberships FOR SELECT TO app_readonly USING (true);

-- seats belong to a branch, the branch to a tenant
ALTER TABLE core.seats ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api    ON core.seats TO app_api
  USING (EXISTS (SELECT 1 FROM core.branches b WHERE b.id = branch_id AND b.tenant_id::text = current_setting('app.tenant_id', true)))
  WITH CHECK (EXISTS (SELECT 1 FROM core.branches b WHERE b.id = branch_id AND b.tenant_id::text = current_setting('app.tenant_id', true)));
CREATE POLICY p_platform_api  ON core.seats TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all    ON core.seats TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_adapter_read  ON core.seats FOR SELECT TO app_adapter USING (true);
CREATE POLICY p_readonly_all  ON core.seats FOR SELECT TO app_readonly USING (true);

COMMIT;

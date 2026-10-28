BEGIN;
DROP POLICY IF EXISTS p_readonly_all ON core.seats; DROP POLICY IF EXISTS p_adapter_read ON core.seats; DROP POLICY IF EXISTS p_worker_all ON core.seats;
DROP POLICY IF EXISTS p_platform_api ON core.seats; DROP POLICY IF EXISTS p_tenant_api ON core.seats; ALTER TABLE core.seats DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_readonly_all ON core.tenant_memberships; DROP POLICY IF EXISTS p_worker_all ON core.tenant_memberships;
DROP POLICY IF EXISTS p_platform_api ON core.tenant_memberships; DROP POLICY IF EXISTS p_tenant_api ON core.tenant_memberships; ALTER TABLE core.tenant_memberships DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_readonly_all ON core.tenants; DROP POLICY IF EXISTS p_worker_all ON core.tenants;
DROP POLICY IF EXISTS p_platform_api ON core.tenants; DROP POLICY IF EXISTS p_tenant_api ON core.tenants; ALTER TABLE core.tenants DISABLE ROW LEVEL SECURITY;
DROP FUNCTION IF EXISTS core.active_memberships_of(uuid);
COMMIT;

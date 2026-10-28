BEGIN;
DROP TABLE IF EXISTS core.change_requests;
DROP TABLE IF EXISTS core.tenant_logos;
ALTER TABLE core.branches DROP COLUMN IF EXISTS created_by, DROP COLUMN IF EXISTS version;
DROP INDEX IF EXISTS core.idx_tenants_onboarded_by;
ALTER TABLE core.tenants DROP COLUMN IF EXISTS onboarded_by;
COMMIT;

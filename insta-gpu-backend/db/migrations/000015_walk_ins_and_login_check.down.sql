BEGIN;
DROP FUNCTION IF EXISTS integration.adopt_walk_in(uuid, integer);
DROP TABLE IF EXISTS integration.horizon_login_check;
ALTER TABLE core.tenants DROP COLUMN IF EXISTS auto_start_walk_ins;
COMMIT;

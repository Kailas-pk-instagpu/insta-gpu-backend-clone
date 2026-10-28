BEGIN;
DROP TABLE IF EXISTS identity.user_avatars;
ALTER TABLE identity.users DROP COLUMN IF EXISTS address, DROP COLUMN IF EXISTS phone;
DROP TABLE IF EXISTS core.spend_limit_alerts;
ALTER TABLE core.branches DROP COLUMN IF EXISTS daily_spend_limit_minor;
COMMIT;

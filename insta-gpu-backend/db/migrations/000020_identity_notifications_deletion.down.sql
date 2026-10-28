BEGIN;
DROP TABLE IF EXISTS identity.account_deletion_requests;
DROP TABLE IF EXISTS identity.notifications;
DROP INDEX IF EXISTS core.idx_membership_user;
DROP INDEX IF EXISTS core.uq_membership_active;
ALTER TABLE identity.users DROP COLUMN IF EXISTS created_by;
COMMIT;

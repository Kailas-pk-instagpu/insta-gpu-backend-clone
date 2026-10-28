BEGIN;
DROP INDEX core.uq_tenants_ad_group;
ALTER TABLE core.tenants DROP COLUMN vdas_procured, DROP COLUMN ad_group;
ALTER TABLE commercial.commercial_accounts DROP COLUMN hold_grace_days;
COMMIT;

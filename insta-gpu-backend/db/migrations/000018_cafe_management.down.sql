BEGIN;
ALTER TABLE billing.invoice_lines DROP COLUMN IF EXISTS discount_minor, DROP COLUMN IF EXISTS list_rate_minor_per_hour;
UPDATE core.branches SET status = 'INACTIVE' WHERE status = 'PENDING';
ALTER TABLE core.branches DROP CONSTRAINT IF EXISTS branches_status_check;
ALTER TABLE core.branches ADD CONSTRAINT branches_status_check CHECK (status IN ('ACTIVE','INACTIVE','SUSPENDED','PAYMENT_HOLD','MAINTENANCE','CLOSED'));
ALTER TABLE core.branches DROP COLUMN IF EXISTS address;
COMMIT;

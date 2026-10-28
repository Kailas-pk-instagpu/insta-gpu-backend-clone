BEGIN;
ALTER TABLE billing.invoice_lines DROP COLUMN IF EXISTS branch_id;
COMMIT;

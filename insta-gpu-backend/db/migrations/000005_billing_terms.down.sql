BEGIN;
ALTER TABLE billing.invoice_lines DROP COLUMN IF EXISTS billed_hours;
ALTER TABLE billing.invoices DROP CONSTRAINT IF EXISTS invoices_cycle_check;
ALTER TABLE billing.invoices ADD CONSTRAINT invoices_cycle_check CHECK (cycle IN ('DAILY','MONTHLY'));
ALTER TABLE commercial.commercial_accounts DROP CONSTRAINT IF EXISTS commercial_accounts_discount_window;
ALTER TABLE commercial.commercial_accounts
  DROP COLUMN IF EXISTS discount_valid_until, DROP COLUMN IF EXISTS discount_valid_from,
  DROP COLUMN IF EXISTS discount_rate_minor_per_hour, DROP COLUMN IF EXISTS standard_rate_minor_per_hour;
UPDATE commercial.commercial_accounts SET billing_cycle = 'DAILY' WHERE billing_cycle = 'WEEKLY';
ALTER TABLE commercial.commercial_accounts DROP CONSTRAINT IF EXISTS commercial_accounts_billing_cycle_check;
ALTER TABLE commercial.commercial_accounts ADD CONSTRAINT commercial_accounts_billing_cycle_check CHECK (billing_cycle IN ('DAILY','MONTHLY'));
COMMIT;

-- 000005 Flexible billing terms per cafe (business rules of 2026-10-12)
--  1. Billing cycle per cafe: DAILY or WEEKLY (week = Monday 00:00 to Sunday 24:00 Asia/Kuala_Lumpur). MONTHLY stays allowed but unused.
--  2. Rate per cafe (not per branch): a standard hourly rate and an optional discounted rate with a validity window.
--     The discount applies to business dates in [discount_valid_from, discount_valid_until); after that the standard rate applies.
--  3. Invoices can be WEEKLY. Lines record the billed (rounded-up) hours next to the exact connected seconds.
-- Rate columns are NULL when unset: the billing run then falls back to the active pricing plan (older behaviour).
BEGIN;

ALTER TABLE commercial.commercial_accounts DROP CONSTRAINT IF EXISTS commercial_accounts_billing_cycle_check;
ALTER TABLE commercial.commercial_accounts ADD CONSTRAINT commercial_accounts_billing_cycle_check CHECK (billing_cycle IN ('DAILY','WEEKLY','MONTHLY'));

ALTER TABLE commercial.commercial_accounts
  ADD COLUMN standard_rate_minor_per_hour bigint CHECK (standard_rate_minor_per_hour IS NULL OR standard_rate_minor_per_hour >= 0),
  ADD COLUMN discount_rate_minor_per_hour bigint CHECK (discount_rate_minor_per_hour IS NULL OR discount_rate_minor_per_hour >= 0),
  ADD COLUMN discount_valid_from timestamptz,
  ADD COLUMN discount_valid_until timestamptz,
  ADD CONSTRAINT commercial_accounts_discount_window CHECK (discount_valid_until IS NULL OR discount_valid_from IS NULL OR discount_valid_until > discount_valid_from);

-- Existing cafes get the confirmed standard rate of RM 9.00 per hour.
UPDATE commercial.commercial_accounts SET standard_rate_minor_per_hour = 900 WHERE standard_rate_minor_per_hour IS NULL;

ALTER TABLE billing.invoices DROP CONSTRAINT IF EXISTS invoices_cycle_check;
ALTER TABLE billing.invoices ADD CONSTRAINT invoices_cycle_check CHECK (cycle IN ('DAILY','WEEKLY','MONTHLY'));

ALTER TABLE billing.invoice_lines ADD COLUMN billed_hours integer CHECK (billed_hours IS NULL OR billed_hours >= 0);

COMMIT;

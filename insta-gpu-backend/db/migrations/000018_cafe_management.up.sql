-- 000018 Cafe management (MoM 2026-10-21): branch address, approval of cafes and branches created by sales (PENDING), soft delete
-- (CLOSED, unchanged value), and the discount shown explicitly on statement lines.
BEGIN;

ALTER TABLE core.branches ADD COLUMN address text CHECK (address IS NULL OR char_length(address) <= 300);

-- PENDING = created by sales, waiting for the super admin's approval (no sessions can start: only ACTIVE branches start sessions).
ALTER TABLE core.branches DROP CONSTRAINT IF EXISTS branches_status_check;
ALTER TABLE core.branches ADD CONSTRAINT branches_status_check
  CHECK (status IN ('ACTIVE','PENDING','INACTIVE','SUSPENDED','PAYMENT_HOLD','MAINTENANCE','CLOSED'));

-- The list price and the discount of a statement line (e.g. RM 9.00/h listed, RM 3.00/h off = billed at RM 6.00/h). NULL on older lines and
-- when no discount applied. subtotal_minor stays the amount actually charged, so totals and the ledger are unchanged.
ALTER TABLE billing.invoice_lines
  ADD COLUMN list_rate_minor_per_hour integer CHECK (list_rate_minor_per_hour IS NULL OR list_rate_minor_per_hour >= 0),
  ADD COLUMN discount_minor bigint CHECK (discount_minor IS NULL OR discount_minor >= 0);

COMMIT;

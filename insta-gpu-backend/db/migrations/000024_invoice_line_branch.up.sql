-- 000024 billing-service: the branch a statement line belongs to. One statement per owner per day (D2/D3), lines per branch so the
-- frontend's Branch Billing page shows each branch's hours. NULL on older lines and on lines not tied to a branch.
-- No FK: core.branches belongs to cafe-management-service.
BEGIN;
ALTER TABLE billing.invoice_lines ADD COLUMN branch_id uuid;
CREATE INDEX idx_invoice_lines_branch ON billing.invoice_lines (branch_id) WHERE branch_id IS NOT NULL;
COMMIT;

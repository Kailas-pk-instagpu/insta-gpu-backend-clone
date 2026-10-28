-- 000009 Invoice documents and billing corrections (decisions 2026-10-13)
--  1. Invoice document: who is billed (company details of the cafe) and who bills (InstaGPU) are COPIED onto each statement when it is issued,
--     together with the tax rate that applied, so an issued document never changes when someone edits a profile later.
--  2. Corrections after issue: credit notes (reduce what a cafe owes or record a refund due), debit notes (extra connected hours found after
--     the statement was issued; payable like a statement), and voiding a wrong statement so it can be re-billed.
BEGIN;

ALTER TABLE core.tenants
  ADD COLUMN address text CHECK (address IS NULL OR length(address) <= 500),
  ADD COLUMN registration_no text CHECK (registration_no IS NULL OR length(registration_no) <= 60),      -- SSM company number
  ADD COLUMN tax_registration_no text CHECK (tax_registration_no IS NULL OR length(tax_registration_no) <= 60), -- SST / TIN of the cafe
  ADD COLUMN billing_email text CHECK (billing_email IS NULL OR length(billing_email) <= 200);

ALTER TABLE billing.invoices
  ADD COLUMN doc_type text NOT NULL DEFAULT 'STATEMENT' CHECK (doc_type IN ('STATEMENT','DEBIT_NOTE')),
  ADD COLUMN parent_invoice_id uuid REFERENCES billing.invoices(id),
  ADD COLUMN tax_bps integer NOT NULL DEFAULT 0 CHECK (tax_bps BETWEEN 0 AND 5000),
  ADD COLUMN bill_to jsonb,
  ADD COLUMN issuer jsonb,
  ADD COLUMN reason text,
  ADD COLUMN voided_at timestamptz,
  ADD COLUMN voided_reason text,
  ADD CONSTRAINT invoices_debit_note_parent CHECK ((doc_type = 'DEBIT_NOTE') = (parent_invoice_id IS NOT NULL));
CREATE INDEX idx_invoices_parent ON billing.invoices(parent_invoice_id) WHERE parent_invoice_id IS NOT NULL;

-- One STATEMENT per account, cycle and period; debit notes are extra documents and do not take the slot.
DROP INDEX billing.uq_invoice_account_day;
CREATE UNIQUE INDEX uq_invoice_account_day ON billing.invoices(commercial_account_id, cycle, business_date) WHERE status <> 'VOID' AND doc_type = 'STATEMENT';

CREATE SEQUENCE billing.adjustment_number_seq;

CREATE TABLE billing.credit_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number text NOT NULL UNIQUE,
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  commercial_account_id uuid NOT NULL REFERENCES commercial.commercial_accounts(id),
  invoice_id uuid NOT NULL REFERENCES billing.invoices(id),
  subtotal_minor bigint NOT NULL CHECK (subtotal_minor > 0),
  tax_minor bigint NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor = subtotal_minor + tax_minor),
  applied_minor bigint NOT NULL CHECK (applied_minor >= 0 AND applied_minor <= total_minor),     -- taken off what the cafe still owed
  refund_due_minor bigint NOT NULL CHECK (refund_due_minor = total_minor - applied_minor),         -- part of an already-paid amount: finance pays it back outside the platform
  reason text NOT NULL CHECK (length(reason) BETWEEN 10 AND 500),
  created_by uuid REFERENCES identity.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_credit_notes_invoice ON billing.credit_notes(invoice_id);
CREATE INDEX idx_credit_notes_tenant ON billing.credit_notes(tenant_id, created_at DESC);
CREATE TRIGGER trg_credit_notes_append_only BEFORE UPDATE OR DELETE ON billing.credit_notes
  FOR EACH ROW EXECUTE FUNCTION integration.forbid_mutation();

ALTER TABLE commercial.payment_hold_events DROP CONSTRAINT IF EXISTS payment_hold_events_action_check;
ALTER TABLE commercial.payment_hold_events ADD CONSTRAINT payment_hold_events_action_check
  CHECK (action IN ('APPLIED','LIFTED_BY_PAYMENT','LIFTED_BY_OVERRIDE','LIFTED_BY_CORRECTION','SUPPRESSED_PSP_OUTAGE'));

GRANT SELECT, INSERT ON billing.credit_notes TO app_api, app_worker;
GRANT SELECT ON billing.credit_notes TO app_readonly;
GRANT USAGE ON SEQUENCE billing.adjustment_number_seq TO app_api, app_worker;
GRANT UPDATE (address, registration_no, tax_registration_no, billing_email, legal_name, updated_at) ON core.tenants TO app_api;

ALTER TABLE billing.credit_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON billing.credit_notes TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON billing.credit_notes TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON billing.credit_notes TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON billing.credit_notes FOR SELECT TO app_readonly USING (true);

COMMIT;

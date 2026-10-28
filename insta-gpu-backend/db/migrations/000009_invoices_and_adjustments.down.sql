BEGIN;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM billing.credit_notes) OR EXISTS (SELECT 1 FROM billing.invoices WHERE doc_type = 'DEBIT_NOTE') THEN
    RAISE EXCEPTION 'credit or debit notes exist: they are financial records and cannot be dropped by a down migration';
  END IF;
END $$;
DROP TABLE billing.credit_notes;
UPDATE commercial.payment_hold_events SET action = 'LIFTED_BY_PAYMENT' WHERE action = 'LIFTED_BY_CORRECTION';
ALTER TABLE commercial.payment_hold_events DROP CONSTRAINT payment_hold_events_action_check;
ALTER TABLE commercial.payment_hold_events ADD CONSTRAINT payment_hold_events_action_check CHECK (action IN ('APPLIED','LIFTED_BY_PAYMENT','LIFTED_BY_OVERRIDE','SUPPRESSED_PSP_OUTAGE'));
DROP SEQUENCE billing.adjustment_number_seq;
DROP INDEX billing.uq_invoice_account_day;
CREATE UNIQUE INDEX uq_invoice_account_day ON billing.invoices(commercial_account_id, cycle, business_date) WHERE status <> 'VOID';
ALTER TABLE billing.invoices DROP CONSTRAINT invoices_debit_note_parent;
DROP INDEX billing.idx_invoices_parent;
ALTER TABLE billing.invoices DROP COLUMN doc_type, DROP COLUMN parent_invoice_id, DROP COLUMN tax_bps, DROP COLUMN bill_to, DROP COLUMN issuer, DROP COLUMN reason, DROP COLUMN voided_at, DROP COLUMN voided_reason;
ALTER TABLE core.tenants DROP COLUMN address, DROP COLUMN registration_no, DROP COLUMN tax_registration_no, DROP COLUMN billing_email;
COMMIT;

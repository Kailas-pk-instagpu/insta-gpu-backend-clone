-- Down migrations are for local/dev only. Never run in production; roll forward instead.
BEGIN;
DROP TRIGGER IF EXISTS trg_journal_balanced ON ledger.journal_lines;
DROP TRIGGER IF EXISTS trg_audit_append_only ON audit.events;
DROP TRIGGER IF EXISTS trg_journal_entries_no_delete ON ledger.journal_entries;
DROP TRIGGER IF EXISTS trg_journal_lines_append_only ON ledger.journal_lines;
DROP FUNCTION IF EXISTS ledger.assert_entry_balanced();
DROP FUNCTION IF EXISTS integration.forbid_mutation();
DROP TABLE IF EXISTS integration.idempotency_keys, payments.provider_outages, commercial.payment_hold_events,
  gaming.horizon_observations;
ALTER TABLE billing.invoices DROP CONSTRAINT IF EXISTS fk_invoice_billing_run;
DROP TABLE IF EXISTS billing.billing_runs;
COMMIT;

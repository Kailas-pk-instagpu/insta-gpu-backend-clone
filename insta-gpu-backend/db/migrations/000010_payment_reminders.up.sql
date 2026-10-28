-- 000010 Payment reminders: one row per (statement, reminder kind) so each reminder is sent exactly once, even with two workers running.
BEGIN;
CREATE TABLE billing.reminders (
  invoice_id uuid NOT NULL REFERENCES billing.invoices(id),
  kind text NOT NULL CHECK (kind ~ '^DUE_[0-9]{1,3}H$'),
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (invoice_id, kind)
);
GRANT SELECT, INSERT ON billing.reminders TO app_worker;
GRANT SELECT ON billing.reminders TO app_readonly;
COMMIT;

-- 000002 V1 pilot deltas (see docs/adr/ADR-003-v1-daily-postpaid.md and ADR-004-no-game-catalog.md)
--  1. No game catalog: sessions no longer need a game; gamers have no accounts in V1.
--  2. V1 session states (staff-started, Horizon-observed).
--  3. Seat <-> Horizon kiosk user mapping (one Horizon user per seat) for session correlation.
--  4. Daily postpaid billing: account billing cycle, payment hold, daily statement fields, billing runs.
--  5. RN-01: only GAMING_SERVICE_TIME is billable.
--  6. API idempotency store, PSP outage windows, append-only guards for ledger + audit.
BEGIN;

-- 1. No catalog / no gamer accounts
ALTER TABLE gaming.sessions ALTER COLUMN requested_game_id DROP NOT NULL;
ALTER TABLE gaming.sessions ALTER COLUMN gamer_id DROP NOT NULL;
COMMENT ON TABLE gaming.games IS 'Not used in V1 (no game catalog). Kept for Phase 2.';
COMMENT ON TABLE gaming.game_runs IS 'Not used in V1 (no in-VM game agent). Kept for Phase 2.';

-- 2. V1 session states + who started/ended it
ALTER TABLE gaming.sessions DROP CONSTRAINT IF EXISTS sessions_status_check;
ALTER TABLE gaming.sessions ADD CONSTRAINT sessions_status_check CHECK (status IN (
  'REQUESTED','ACCEPTED','REJECTED','CONNECTING','ACTIVE','DISCONNECTED',
  'ENDING','FINALIZING','COMPLETED','CANCELLED','ABANDONED','FAILED'));
ALTER TABLE gaming.sessions
  ADD COLUMN started_by_user_id uuid REFERENCES identity.users(id),
  ADD COLUMN ended_by_user_id uuid REFERENCES identity.users(id),
  ADD COLUMN rejection_code text,
  ADD COLUMN disconnected_at timestamptz,
  ADD COLUMN finalized_at timestamptz,
  ADD COLUMN version integer NOT NULL DEFAULT 0;
-- one open session per seat
CREATE UNIQUE INDEX uq_open_session_per_seat ON gaming.sessions(seat_id)
  WHERE status IN ('REQUESTED','ACCEPTED','CONNECTING','ACTIVE','DISCONNECTED','ENDING');

-- 3. Seat <-> Horizon kiosk user
ALTER TABLE core.seats ADD COLUMN horizon_username text;
CREATE UNIQUE INDEX uq_seat_horizon_username ON core.seats(lower(horizon_username)) WHERE horizon_username IS NOT NULL;

-- Horizon observations (raw, append-only) used to compute billable intervals
CREATE TABLE gaming.horizon_observations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id uuid REFERENCES gaming.sessions(id),
  horizon_session_id text NOT NULL,
  horizon_username text NOT NULL,
  machine_name text,
  state text NOT NULL CHECK (state IN ('CONNECTED','DISCONNECTED','ENDED','UNKNOWN')),
  observed_at timestamptz NOT NULL,
  source text NOT NULL DEFAULT 'POLL' CHECK (source IN ('POLL','AUDIT_EVENT','RECONCILE')),
  raw jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (horizon_session_id, state, observed_at)
);
CREATE INDEX idx_horizon_obs_session ON gaming.horizon_observations(session_id, observed_at);

-- 4. Daily postpaid + payment hold
ALTER TABLE commercial.commercial_accounts
  ADD COLUMN billing_cycle text NOT NULL DEFAULT 'DAILY' CHECK (billing_cycle IN ('DAILY','MONTHLY')),
  ADD COLUMN hold_since timestamptz,
  ADD COLUMN hold_reason text,
  ADD COLUMN hold_override_until timestamptz,
  ADD COLUMN hold_override_by uuid REFERENCES identity.users(id),
  ADD COLUMN version integer NOT NULL DEFAULT 0;
ALTER TABLE commercial.commercial_accounts DROP CONSTRAINT IF EXISTS commercial_accounts_status_check;
ALTER TABLE commercial.commercial_accounts ADD CONSTRAINT commercial_accounts_status_check
  CHECK (status IN ('ACTIVE','PAYMENT_HOLD','SUSPENDED','CLOSED'));
ALTER TABLE commercial.commercial_accounts ALTER COLUMN billing_mode SET DEFAULT 'POSTPAID';

CREATE TABLE commercial.payment_hold_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commercial_account_id uuid NOT NULL REFERENCES commercial.commercial_accounts(id),
  action text NOT NULL CHECK (action IN ('APPLIED','LIFTED_BY_PAYMENT','LIFTED_BY_OVERRIDE','SUPPRESSED_PSP_OUTAGE')),
  reason text NOT NULL,
  statement_ids uuid[] NOT NULL DEFAULT '{}',
  actor_type text NOT NULL CHECK (actor_type IN ('SYSTEM','USER')),
  actor_user_id uuid REFERENCES identity.users(id),
  correlation_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_hold_events_account ON commercial.payment_hold_events(commercial_account_id, occurred_at DESC);

-- Daily statement = billing.invoices with cycle DAILY
ALTER TABLE billing.invoices
  ADD COLUMN tenant_id uuid REFERENCES core.tenants(id),
  ADD COLUMN cycle text NOT NULL DEFAULT 'DAILY' CHECK (cycle IN ('DAILY','MONTHLY')),
  ADD COLUMN business_date date,
  ADD COLUMN period_start timestamptz,
  ADD COLUMN period_end timestamptz,
  ADD COLUMN paid_at timestamptz,
  ADD COLUMN billing_run_id uuid,
  ADD COLUMN policy_version text NOT NULL DEFAULT 'v1';
CREATE UNIQUE INDEX uq_invoice_account_day ON billing.invoices(commercial_account_id, cycle, business_date) WHERE status <> 'VOID';

ALTER TABLE billing.invoice_lines
  ADD COLUMN resource_profile text,
  ADD COLUMN billable_seconds bigint,
  ADD COLUMN rate_minor_per_hour bigint;

ALTER TABLE billing.charges
  ADD COLUMN business_date date,
  ADD COLUMN invoice_id uuid REFERENCES billing.invoices(id);
CREATE UNIQUE INDEX uq_charge_session_day ON billing.charges(session_id, business_date) WHERE status <> 'VOIDED';

CREATE TABLE billing.billing_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_date date NOT NULL,
  status text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','SUCCEEDED','FAILED','PARTIAL')),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  accounts_total integer NOT NULL DEFAULT 0,
  accounts_billed integer NOT NULL DEFAULT 0,
  accounts_failed integer NOT NULL DEFAULT 0,
  error text,
  triggered_by text NOT NULL DEFAULT 'SCHEDULE'
);
CREATE INDEX idx_billing_runs_date ON billing.billing_runs(business_date, started_at DESC);
ALTER TABLE billing.invoices ADD CONSTRAINT fk_invoice_billing_run FOREIGN KEY (billing_run_id) REFERENCES billing.billing_runs(id);

-- 5. RN-01: only GAMING_SERVICE_TIME is billable in V1
UPDATE commercial.usage_meters SET billable_by_default = false WHERE code = 'PLAYABLE_GAMING_TIME';
INSERT INTO commercial.usage_meters(code, name, unit, billable_by_default)
VALUES ('GAMING_SERVICE_TIME','Gaming service time (Horizon connected + disconnect grace)','second',true)
ON CONFLICT (code) DO UPDATE SET billable_by_default = true;
ALTER TABLE commercial.usage_records ADD COLUMN business_date date;
CREATE UNIQUE INDEX uq_usage_segment ON commercial.usage_records(session_id, meter_id, start_at);

-- Payments: statement payments + manual payments
ALTER TABLE payments.payment_orders
  ADD COLUMN invoice_id uuid REFERENCES billing.invoices(id),
  ADD COLUMN method text CHECK (method IN ('DUITNOW_QR','FPX','BANK_TRANSFER','OTHER')),
  ADD COLUMN manual_reference text,
  ADD COLUMN recorded_by uuid REFERENCES identity.users(id),
  ADD COLUMN succeeded_at timestamptz;
CREATE INDEX idx_payment_orders_invoice ON payments.payment_orders(invoice_id);
CREATE INDEX idx_payment_orders_pending ON payments.payment_orders(status, created_at) WHERE status IN ('CREATED','PENDING','PROCESSING');

CREATE TABLE payments.provider_outages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  source text NOT NULL CHECK (source IN ('HEALTH_CHECK','MANUAL')),
  note text,
  created_by uuid REFERENCES identity.users(id),
  CHECK (ended_at IS NULL OR ended_at > started_at)
);

-- 6. Idempotency store for mutating API calls
CREATE TABLE integration.idempotency_keys (
  scope text NOT NULL,              -- e.g. tenant_id or 'platform'
  key text NOT NULL CHECK (length(key) BETWEEN 8 AND 200),
  request_hash text NOT NULL,
  method text NOT NULL,
  path text NOT NULL,
  response_status integer,
  response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '24 hours',
  PRIMARY KEY (scope, key)
);
CREATE INDEX idx_idempotency_expiry ON integration.idempotency_keys(expires_at);

-- BFF looks sessions up by the hash of the opaque cookie value
CREATE INDEX idx_bff_sessions_sid_hash ON identity.bff_sessions ((metadata->>'sid_hash'));

-- Chart of accounts (platform-level, illustrative; finance to confirm)
INSERT INTO ledger.accounts(commercial_account_id, code, name, account_type)
SELECT NULL, v.code, v.name, v.t FROM (VALUES
  ('1000','Bank','ASSET'),
  ('1100','PSP clearing','ASSET'),
  ('1200','Accounts receivable - cafes','RECEIVABLE'),
  ('2300','Tax payable','LIABILITY'),
  ('4000','Gaming service revenue','REVENUE'),
  ('5100','PSP fees','EXPENSE')) AS v(code, name, t)
WHERE NOT EXISTS (SELECT 1 FROM ledger.accounts a WHERE a.commercial_account_id IS NULL AND a.code = v.code);
CREATE UNIQUE INDEX uq_ledger_platform_account_code ON ledger.accounts(code) WHERE commercial_account_id IS NULL;

-- Append-only guards: posted money and audit history never change
CREATE OR REPLACE FUNCTION integration.forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% on %.% is not allowed (append-only). Post a compensating entry instead.', TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME
    USING ERRCODE = 'insufficient_privilege';
END $$;
CREATE TRIGGER trg_journal_lines_append_only BEFORE UPDATE OR DELETE ON ledger.journal_lines
  FOR EACH ROW EXECUTE FUNCTION integration.forbid_mutation();
CREATE TRIGGER trg_journal_entries_no_delete BEFORE DELETE ON ledger.journal_entries
  FOR EACH ROW EXECUTE FUNCTION integration.forbid_mutation();
CREATE TRIGGER trg_audit_append_only BEFORE UPDATE OR DELETE ON audit.events
  FOR EACH ROW EXECUTE FUNCTION integration.forbid_mutation();

-- Journal must balance: checked at commit time
CREATE OR REPLACE FUNCTION ledger.assert_entry_balanced() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE dr bigint; cr bigint; n int;
BEGIN
  SELECT coalesce(sum(debit_minor),0), coalesce(sum(credit_minor),0), count(*) INTO dr, cr, n
  FROM ledger.journal_lines WHERE journal_entry_id = NEW.journal_entry_id;
  IF n < 2 OR dr <> cr THEN
    RAISE EXCEPTION 'journal % unbalanced: debit % credit % lines %', NEW.journal_entry_id, dr, cr, n;
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER trg_journal_balanced AFTER INSERT ON ledger.journal_lines
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION ledger.assert_entry_balanced();

COMMIT;

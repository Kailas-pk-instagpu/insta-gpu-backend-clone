-- 000004 Horizon sync state + the infra-adapter's real permissions.
-- Why: the adapter was written against the superuser. Under its own login (app_adapter) it could not see sessions at all
-- (RLS has no policy for it) and could not update them (SELECT-only grant), so the whole Horizon sync was inert.
-- The adapter is cross-tenant by nature; it gets explicit policies and COLUMN-level UPDATE rights only on what it must change.
BEGIN;

ALTER TABLE gaming.sessions
  ADD COLUMN horizon_missing_since timestamptz,        -- first poll where the seat's Horizon session was absent (debounce)
  ADD COLUMN horizon_logoff_requested_at timestamptz,  -- last time the adapter asked Horizon to log this session off
  ADD COLUMN horizon_last_seen_at timestamptz;         -- last poll in which Horizon showed this session alive (observations only store CHANGES, so they cannot answer this)

-- Pricing profile: V1 has no fixed seat->machine assignment (instant clones float), so the seat carries the profile it is sold as and
-- a session snapshots it at start. Billing reads the snapshot, so changing a seat later never rewrites history.
ALTER TABLE core.seats ADD COLUMN resource_profile text;
ALTER TABLE gaming.sessions ADD COLUMN resource_profile text;
UPDATE core.seats SET resource_profile = 'L40S-8GB' WHERE resource_profile IS NULL;

-- Freshness of each sync loop (HorizonSyncStale alert reads this).
CREATE TABLE integration.sync_status (
  name text PRIMARY KEY,
  last_success_at timestamptz,
  last_error_at timestamptz,
  last_error text,
  consecutive_failures integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON integration.sync_status TO app_api, app_worker, app_readonly;
GRANT SELECT, INSERT, UPDATE ON integration.sync_status TO app_adapter;

-- Adapter: read all sessions, change only lifecycle columns; write audit rows (no tenant context).
GRANT UPDATE (status, billable_started_at, disconnected_at, ended_at, finalized_at, termination_reason,
              horizon_missing_since, horizon_logoff_requested_at, horizon_last_seen_at, version) ON gaming.sessions TO app_adapter;
CREATE POLICY p_adapter_sessions ON gaming.sessions TO app_adapter USING (true) WITH CHECK (true);
CREATE POLICY p_adapter_audit_insert ON audit.events FOR INSERT TO app_adapter WITH CHECK (true);

-- A session being abandoned/finalised still occupies its seat until Horizon has logged the user off; otherwise a new session could
-- start on the seat and be billed from the previous gamer's lingering Horizon session.
DROP INDEX IF EXISTS gaming.uq_open_session_per_seat;
CREATE UNIQUE INDEX uq_open_session_per_seat ON gaming.sessions(seat_id)
  WHERE status IN ('REQUESTED','ACCEPTED','CONNECTING','ACTIVE','DISCONNECTED','ENDING','ABANDONED','FINALIZING');

COMMIT;

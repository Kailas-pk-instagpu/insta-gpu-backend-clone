BEGIN;
DROP POLICY IF EXISTS p_adapter_audit_insert ON audit.events;
DROP POLICY IF EXISTS p_adapter_sessions ON gaming.sessions;
REVOKE UPDATE (status, billable_started_at, disconnected_at, ended_at, finalized_at, termination_reason,
               horizon_missing_since, horizon_logoff_requested_at, horizon_last_seen_at, version) ON gaming.sessions FROM app_adapter;
DROP INDEX IF EXISTS gaming.uq_open_session_per_seat;
CREATE UNIQUE INDEX uq_open_session_per_seat ON gaming.sessions(seat_id)
  WHERE status IN ('REQUESTED','ACCEPTED','CONNECTING','ACTIVE','DISCONNECTED','ENDING');
DROP TABLE IF EXISTS integration.sync_status;
ALTER TABLE gaming.sessions DROP COLUMN IF EXISTS resource_profile;
ALTER TABLE core.seats DROP COLUMN IF EXISTS resource_profile;
ALTER TABLE gaming.sessions DROP COLUMN IF EXISTS horizon_last_seen_at;
ALTER TABLE gaming.sessions DROP COLUMN IF EXISTS horizon_logoff_requested_at, DROP COLUMN IF EXISTS horizon_missing_since;
COMMIT;

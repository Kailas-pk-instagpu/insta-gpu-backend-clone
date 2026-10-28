-- 000014 Horizon sessions with no session started in the app ("someone signed in to Horizon without Start", or a login that is no seat).
-- The infra adapter keeps this table equal to what it sees on every poll (rows appear and disappear with the Horizon session);
-- the API only reads it for the floor (the seat it belongs to) and the staff home page. Nothing here is billed.
BEGIN;
CREATE TABLE integration.horizon_unmatched (
  horizon_session_id text PRIMARY KEY,
  user_name text NOT NULL,
  seat_id uuid REFERENCES core.seats(id) ON DELETE SET NULL,   -- NULL: the login is not any seat's Horizon sign-in
  why text NOT NULL CHECK (why IN ('NO_OPEN_SESSION', 'UNKNOWN_USER')),
  first_seen_at timestamptz NOT NULL,
  last_seen_at timestamptz NOT NULL
);
CREATE INDEX ix_horizon_unmatched_seat ON integration.horizon_unmatched(seat_id) WHERE seat_id IS NOT NULL;
GRANT SELECT, INSERT, UPDATE, DELETE ON integration.horizon_unmatched TO app_adapter;
GRANT SELECT ON integration.horizon_unmatched TO app_api, app_worker, app_readonly;
COMMIT;

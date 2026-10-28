-- 000012 Horizon snapshot: the infra adapter (the only process with Horizon credentials) writes a small summary of the pools and
-- machines it saw (about once a minute); the API only reads it for the staff home page. No Horizon credentials ever reach the API.
BEGIN;
CREATE TABLE integration.horizon_snapshot (
  id text PRIMARY KEY,
  taken_at timestamptz NOT NULL,
  data jsonb NOT NULL
);
GRANT SELECT, INSERT, UPDATE ON integration.horizon_snapshot TO app_adapter;
GRANT SELECT ON integration.horizon_snapshot TO app_api, app_worker, app_readonly;
COMMIT;

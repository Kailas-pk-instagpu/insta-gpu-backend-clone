-- 000015 (1) Per-cafe "bill walk-ins automatically": a seat's Horizon login that connects without Start gets a session at once (billing from connect).
--       (2) Does the seat's Horizon sign-in exist in AD? The infra adapter (the only process with Horizon credentials) checks every distinct seat login
--           and stores the answer; the API only reads it for the Setup screen and the staff home.
BEGIN;

ALTER TABLE core.tenants ADD COLUMN auto_start_walk_ins boolean NOT NULL DEFAULT false;
GRANT UPDATE (auto_start_walk_ins) ON core.tenants TO app_api;

CREATE TABLE integration.horizon_login_check (
  login text PRIMARY KEY,                    -- as matched against Horizon: no DOMAIN\ and no @suffix, lower case
  found boolean NOT NULL,
  checked_at timestamptz NOT NULL
);
GRANT SELECT, INSERT, UPDATE, DELETE ON integration.horizon_login_check TO app_adapter;
GRANT SELECT ON integration.horizon_login_check TO app_api, app_worker, app_readonly;

-- One function does every pre-flight check of a staff start (cafe opted in, account ACTIVE, branch ACTIVE, seat in service, no booking reserving
-- it) and creates the ACCEPTED session, so the adapter needs no table rights beyond EXECUTE. Returns nothing when any check fails or the seat is busy.
CREATE FUNCTION integration.adopt_walk_in(p_seat uuid, p_lead_minutes integer)
RETURNS TABLE (out_session_id uuid, out_tenant_id uuid) LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE s record; sid uuid;
BEGIN
  SELECT st.branch_id, st.status AS seat_status, st.resource_profile, b.tenant_id AS tid, b.status AS branch_status, t.auto_start_walk_ins AS auto_on, a.status AS account_status
    INTO s
    FROM core.seats st JOIN core.branches b ON b.id = st.branch_id JOIN core.tenants t ON t.id = b.tenant_id JOIN commercial.commercial_accounts a ON a.tenant_id = t.id
   WHERE st.id = p_seat;
  IF NOT FOUND OR NOT s.auto_on OR s.branch_status <> 'ACTIVE' OR s.account_status <> 'ACTIVE' OR s.seat_status <> 'IDLE' THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM gaming.bookings WHERE seat_id = p_seat AND status = 'BOOKED' AND starts_at - make_interval(mins => p_lead_minutes) <= now() AND hold_until > now()) THEN RETURN; END IF;
  BEGIN
    INSERT INTO gaming.sessions(tenant_id, branch_id, seat_id, status, accepted_at, metadata, resource_profile)
    VALUES (s.tid, s.branch_id, p_seat, 'ACCEPTED', now(), '{"auto_started": true}'::jsonb, s.resource_profile) RETURNING id INTO sid;
  EXCEPTION WHEN unique_violation THEN RETURN;
  END;
  RETURN QUERY SELECT sid, s.tid;
END $$;
REVOKE ALL ON FUNCTION integration.adopt_walk_in(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION integration.adopt_walk_in(uuid, integer) TO app_adapter;

COMMIT;

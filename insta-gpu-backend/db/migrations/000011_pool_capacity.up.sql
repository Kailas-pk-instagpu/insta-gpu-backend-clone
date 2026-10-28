-- 000011 Pool capacity (finding of the Horizon probe 2026-10-13: floating instant-clone pools, one VM per session, VM deleted at logoff).
-- The platform keeps one platform-wide setting "pool_capacity" (how many desktops the Horizon pool can hand out at the same time; 0 or missing = no limit)
-- and counts usage ACROSS cafes (SECURITY DEFINER functions, because each cafe's row-level security only shows that cafe's rows).
BEGIN;

CREATE TABLE core.platform_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_by uuid REFERENCES identity.users(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON core.platform_settings TO app_api, app_worker, app_adapter, app_readonly;
GRANT INSERT, UPDATE ON core.platform_settings TO app_api;

-- Desktops in use right now (open sessions of all cafes) and desktops reserved for bookings that are inside their reservation window.
CREATE FUNCTION core.pool_usage(lead_minutes integer, exclude_booking uuid DEFAULT NULL)
RETURNS TABLE (open_sessions integer, reserved integer) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT (SELECT count(*)::int FROM gaming.sessions WHERE status IN ('ACCEPTED','CONNECTING','ACTIVE','DISCONNECTED')),
         (SELECT count(*)::int FROM gaming.bookings
           WHERE status = 'BOOKED' AND (exclude_booking IS NULL OR id <> exclude_booking)
             AND starts_at - make_interval(mins => lead_minutes) <= now() AND hold_until > now())
$$;

-- Bookings of ALL cafes whose hold period overlaps [from_ts, to_ts).
CREATE FUNCTION core.pool_bookings_overlapping(from_ts timestamptz, to_ts timestamptz)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT count(*)::int FROM gaming.bookings WHERE status = 'BOOKED' AND starts_at < to_ts AND hold_until > from_ts
$$;

REVOKE ALL ON FUNCTION core.pool_usage(integer, uuid), core.pool_bookings_overlapping(timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION core.pool_usage(integer, uuid), core.pool_bookings_overlapping(timestamptz, timestamptz) TO app_api, app_worker;

COMMIT;

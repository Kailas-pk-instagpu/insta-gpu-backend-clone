BEGIN;
DROP FUNCTION core.pool_bookings_overlapping(timestamptz, timestamptz);
DROP FUNCTION core.pool_usage(integer, uuid);
DROP TABLE core.platform_settings;
COMMIT;

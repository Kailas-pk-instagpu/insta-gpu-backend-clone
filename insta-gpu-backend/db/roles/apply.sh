#!/bin/sh
# Applies db/roles after migrations. Used by the compose service `db-roles`; needs PG* connection variables
# (migrator credentials) and one APP_*_DB_PASSWORD per service login.
set -eu
cd "$(dirname "$0")"
psql -v ON_ERROR_STOP=1 -f 01-service-roles.sql
psql -v ON_ERROR_STOP=1 \
  -v bff_pw="$APP_BFF_DB_PASSWORD" \
  -v auth_pw="$APP_AUTH_DB_PASSWORD" \
  -v cafe_pw="$APP_CAFE_DB_PASSWORD" \
  -v session_pw="$APP_SESSION_DB_PASSWORD" \
  -v billing_pw="$APP_BILLING_DB_PASSWORD" \
  -v integration_pw="$APP_INTEGRATION_DB_PASSWORD" \
  -v readonly_pw="$APP_READONLY_DB_PASSWORD" \
  -f 02-logins.sql
echo "db/roles applied"

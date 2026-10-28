-- One database login per service, each a member of its group role from 01-service-roles.sql (reference pattern:
-- app_api_login -> app_api). Passwords are NOT in this file: they come in as psql variables from the environment
-- (compose service `db-roles`; dev values in .env.example, real environments from OpenBao).
--   psql -v bff_pw=... -v auth_pw=... -v cafe_pw=... -v session_pw=... -v billing_pw=... -v integration_pw=... -v readonly_pw=... -f 02-logins.sql
\set ON_ERROR_STOP on

SELECT format('CREATE ROLE %I LOGIN', l) FROM unnest(ARRAY[
  'app_bff_login','app_auth_login','app_cafe_login','app_session_login','app_billing_login','app_integration_login','app_readonly_login'
]) AS l WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = l)
\gexec

ALTER ROLE app_bff_login         LOGIN PASSWORD :'bff_pw';
ALTER ROLE app_auth_login        LOGIN PASSWORD :'auth_pw';
ALTER ROLE app_cafe_login        LOGIN PASSWORD :'cafe_pw';
ALTER ROLE app_session_login     LOGIN PASSWORD :'session_pw';
ALTER ROLE app_billing_login     LOGIN PASSWORD :'billing_pw';
ALTER ROLE app_integration_login LOGIN PASSWORD :'integration_pw';
ALTER ROLE app_readonly_login    LOGIN PASSWORD :'readonly_pw';

GRANT app_bff         TO app_bff_login;
GRANT app_auth        TO app_auth_login;
GRANT app_cafe        TO app_cafe_login;
GRANT app_session     TO app_session_login;
GRANT app_billing     TO app_billing_login;
GRANT app_integration TO app_integration_login;
GRANT app_readonly    TO app_readonly_login;

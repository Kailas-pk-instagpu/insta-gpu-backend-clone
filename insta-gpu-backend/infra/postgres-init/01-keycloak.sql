-- Dev only (runs once, on an empty data volume). Keycloak gets its own database and login, as in the reference.
-- Service logins are created after migrations by db/roles (compose service `db-roles`).
CREATE ROLE keycloak LOGIN PASSWORD 'keycloak';
CREATE DATABASE keycloak OWNER keycloak;

-- 000017 Daily spending limit per branch (with alerts) and user profiles (phone, address, avatar).
BEGIN;

-- Optional limit, in sen, on what one branch spends per Malaysian business day. NULL = no limit. It only ALERTS: sessions are never stopped by it.
ALTER TABLE core.branches ADD COLUMN daily_spend_limit_minor bigint
  CHECK (daily_spend_limit_minor IS NULL OR daily_spend_limit_minor BETWEEN 100 AND 100000000);

-- One row per alert sent (branch, day, level 80 = "close to the limit", 100 = "reached"): claimed in the same transaction as the event, so it is sent once.
CREATE TABLE core.spend_limit_alerts (
  branch_id uuid NOT NULL REFERENCES core.branches(id),
  business_date date NOT NULL,
  level smallint NOT NULL CHECK (level IN (80, 100)),
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  spent_minor bigint NOT NULL,
  limit_minor bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (branch_id, business_date, level)
);
ALTER TABLE core.spend_limit_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON core.spend_limit_alerts TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON core.spend_limit_alerts TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON core.spend_limit_alerts TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON core.spend_limit_alerts FOR SELECT TO app_readonly USING (true);
GRANT SELECT ON core.spend_limit_alerts TO app_api, app_readonly;
GRANT SELECT, INSERT ON core.spend_limit_alerts TO app_worker;

-- Profile fields the person edits themselves. The e-mail stays owned by the sign-in (Keycloak).
ALTER TABLE identity.users
  ADD COLUMN phone text CHECK (phone IS NULL OR char_length(phone) BETWEEN 7 AND 24),
  ADD COLUMN address text CHECK (address IS NULL OR char_length(address) <= 300);

-- Profile picture: a small image (the console resizes it to 256 x 256 before upload). Stored in the database so no file store is needed at pilot scale.
CREATE TABLE identity.user_avatars (
  user_id uuid PRIMARY KEY REFERENCES identity.users(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/png', 'image/jpeg', 'image/webp')),
  data bytea NOT NULL CHECK (octet_length(data) BETWEEN 1 AND 262144),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON identity.user_avatars TO app_api;

COMMIT;

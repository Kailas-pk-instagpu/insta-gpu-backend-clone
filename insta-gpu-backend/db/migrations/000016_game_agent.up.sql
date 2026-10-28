-- 000016 Game agent (trial): a small program in the VDI image reports which Steam account is signed in and which game runs, per seat.
-- ADR-004 removed game tracking from V1; this reverses it for a trial (ADR-012). The old catalog tables (gaming.games / game_runs) stay unused:
-- the agent reports what it SEES (Steam app id + title), so no catalog has to be maintained.
BEGIN;

-- Latest report per seat (what the floor shows).
CREATE TABLE gaming.agent_status (
  seat_id uuid PRIMARY KEY REFERENCES core.seats(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  branch_id uuid NOT NULL REFERENCES core.branches(id),
  machine_name text NOT NULL,
  windows_user text NOT NULL,
  agent_version text NOT NULL,
  steam_account_id text,                    -- SteamID64 only; never a user name, password or token
  game_app_id text,
  game_title text,
  game_since timestamptz,
  verified boolean NOT NULL DEFAULT false,  -- Horizon confirms this user is connected on this machine (snapshot, about a minute old)
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

-- History: one row per run of a game (until the game, the Steam account or the seat's agent changes or stops reporting).
CREATE TABLE gaming.game_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  branch_id uuid NOT NULL REFERENCES core.branches(id),
  seat_id uuid NOT NULL REFERENCES core.seats(id) ON DELETE CASCADE,
  session_id uuid REFERENCES gaming.sessions(id),
  steam_account_id text,
  app_id text NOT NULL,
  title text NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  last_seen_at timestamptz NOT NULL
);
CREATE UNIQUE INDEX uq_game_activity_open ON gaming.game_activity(seat_id) WHERE ended_at IS NULL;
CREATE INDEX ix_game_activity_seat ON gaming.game_activity(seat_id, started_at DESC);
CREATE INDEX ix_game_activity_tenant ON gaming.game_activity(tenant_id, started_at DESC);

ALTER TABLE gaming.agent_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON gaming.agent_status TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON gaming.agent_status TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON gaming.agent_status TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON gaming.agent_status FOR SELECT TO app_readonly USING (true);
ALTER TABLE gaming.game_activity ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON gaming.game_activity TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON gaming.game_activity TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON gaming.game_activity TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON gaming.game_activity FOR SELECT TO app_readonly USING (true);

GRANT SELECT, INSERT, UPDATE ON gaming.agent_status, gaming.game_activity TO app_api;
GRANT SELECT ON gaming.agent_status, gaming.game_activity TO app_worker, app_readonly;

COMMIT;

-- 000019 Parked MoM items (2026-10-21): the GPU node types list, the thin-client agent (agent 1), and a 30-day limit on agent data.
BEGIN;

-- GPU node types: the master list of what a seat can be (8 GB, 16 GB ...). Seats point at one (seats.resource_profile = code).
-- A type is never deleted while seats or old statements use its code: it is switched off (active = false) instead.
-- Billing does not read rates from here (rates are per cafe, ADR-009); statement lines keep the code as text.
CREATE TABLE core.gpu_node_types (
  code text PRIMARY KEY CHECK (code ~ '^[A-Za-z0-9][A-Za-z0-9._-]{1,39}$'),
  name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 80),
  gpu_model text CHECK (gpu_model IS NULL OR char_length(gpu_model) <= 60),
  vram_gb integer NOT NULL CHECK (vram_gb BETWEEN 1 AND 192),
  vgpu_profile text CHECK (vgpu_profile IS NULL OR char_length(vgpu_profile) <= 60),   -- Horizon's name for it, e.g. nvidia_l40-8q
  vcpus integer CHECK (vcpus IS NULL OR vcpus BETWEEN 1 AND 256),
  ram_gb integer CHECK (ram_gb IS NULL OR ram_gb BETWEEN 1 AND 2048),
  notes text CHECK (notes IS NULL OR char_length(notes) <= 500),
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO core.gpu_node_types(code, name, gpu_model, vram_gb, sort_order) VALUES
  ('L40S-8GB', 'L40S 8 GB', 'NVIDIA L40S', 8, 10),
  ('L40S-16GB', 'L40S 16 GB', 'NVIDIA L40S', 16, 20);
-- Every code already on a seat becomes a type, so the foreign key below holds for existing data.
INSERT INTO core.gpu_node_types(code, name, vram_gb, sort_order)
SELECT DISTINCT s.resource_profile, s.resource_profile, COALESCE(NULLIF(substring(s.resource_profile FROM '(\d+)GB'), '')::int, 8), 100
FROM core.seats s WHERE s.resource_profile IS NOT NULL ON CONFLICT (code) DO NOTHING;
ALTER TABLE core.seats ADD CONSTRAINT fk_seat_gpu_node_type FOREIGN KEY (resource_profile) REFERENCES core.gpu_node_types(code) ON UPDATE CASCADE;

-- Platform-wide list: everyone signed in may read it; only a platform-scope transaction (the super admin's API calls) may change it.
ALTER TABLE core.gpu_node_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read_all       ON core.gpu_node_types FOR SELECT TO app_api, app_worker, app_readonly USING (true);
CREATE POLICY p_platform_write ON core.gpu_node_types FOR INSERT TO app_api WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_platform_upd   ON core.gpu_node_types FOR UPDATE TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
GRANT SELECT ON core.gpu_node_types TO app_api, app_worker, app_readonly;
GRANT INSERT, UPDATE ON core.gpu_node_types TO app_api;

-- Thin-client agent: the small computer at the seat that runs the Horizon client. Latest state per machine (what the console shows).
-- seat_id is NULL until the machine is linked to a seat (by the seat login in its config, or by InstaGPU support in the console);
-- unlinked rows have no tenant, so only platform staff see them (RLS).
CREATE TABLE gaming.thin_clients (
  machine_name text PRIMARY KEY CHECK (machine_name = lower(machine_name) AND char_length(machine_name) BETWEEN 1 AND 64),
  seat_id uuid UNIQUE REFERENCES core.seats(id) ON DELETE CASCADE,   -- seats are never deleted in the app; a dev reset that does takes the device row too
  tenant_id uuid REFERENCES core.tenants(id),
  branch_id uuid REFERENCES core.branches(id),
  CHECK ((seat_id IS NULL) = (tenant_id IS NULL) AND (seat_id IS NULL) = (branch_id IS NULL)),
  seat_login text,                                   -- the seat login the agent's config claims (a hint for linking, not proof)
  os text NOT NULL,
  agent_version text NOT NULL,
  uptime_s bigint,
  cpu_pct numeric(5,1) CHECK (cpu_pct IS NULL OR cpu_pct BETWEEN 0 AND 100),
  mem_used_pct numeric(5,1) CHECK (mem_used_pct IS NULL OR mem_used_pct BETWEEN 0 AND 100),
  mem_total_mb integer,
  horizon_client_running boolean NOT NULL DEFAULT false,
  horizon_session_active boolean NOT NULL DEFAULT false,  -- a remote desktop window is open (the Horizon protocol process runs)
  foreground_app text,                               -- the program in front, when the OS can tell (Windows)
  other_apps text[] NOT NULL DEFAULT '{}',           -- watched programs that run besides Horizon (browsers, game launchers ...)
  non_horizon_use boolean NOT NULL DEFAULT false,
  online boolean NOT NULL DEFAULT true,              -- false once it has been silent too long (worker job thin-client-watch)
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_thin_clients_branch ON gaming.thin_clients(branch_id);

-- History, written only on a change (Horizon client started / stopped, other use began / ended, went silent / came back). Kept 30 days.
CREATE TABLE gaming.thin_client_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,          -- order of events written in the same instant
  machine_name text NOT NULL,
  tenant_id uuid REFERENCES core.tenants(id),
  branch_id uuid REFERENCES core.branches(id),
  seat_id uuid REFERENCES core.seats(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK (kind IN ('FIRST_SEEN','ONLINE','SILENT','HORIZON_STARTED','HORIZON_STOPPED','SESSION_OPENED','SESSION_CLOSED','OTHER_USE_STARTED','OTHER_USE_ENDED','LINKED','UNLINKED')),
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_tc_events_machine ON gaming.thin_client_events(machine_name, seq DESC);
CREATE INDEX ix_tc_events_at ON gaming.thin_client_events(at);

ALTER TABLE gaming.thin_clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON gaming.thin_clients TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON gaming.thin_clients TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON gaming.thin_clients TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON gaming.thin_clients FOR SELECT TO app_readonly USING (true);
ALTER TABLE gaming.thin_client_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON gaming.thin_client_events TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON gaming.thin_client_events TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON gaming.thin_client_events TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON gaming.thin_client_events FOR SELECT TO app_readonly USING (true);

GRANT SELECT, INSERT, UPDATE ON gaming.thin_clients, gaming.thin_client_events TO app_api;
GRANT SELECT, INSERT, UPDATE ON gaming.thin_clients, gaming.thin_client_events TO app_worker;
GRANT SELECT ON gaming.thin_clients, gaming.thin_client_events TO app_readonly;

-- Agent data is kept 30 days (MoM; PDPA: SteamIDs and game titles are personal data). The worker job agent-retention deletes older rows.
GRANT DELETE ON gaming.game_activity, gaming.agent_status, gaming.thin_client_events, gaming.thin_clients TO app_worker;

COMMIT;

-- 000022 cafe-management-service (docs/database-design.md §3.2): branch shift schedules, the Floor Managers on each shift, and shift
-- handover notes. Times of day are local branch time (Asia/Kuala_Lumpur); an end before the start means the shift runs past midnight.
BEGIN;

CREATE TABLE core.shifts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES core.tenants(id),
  branch_id   uuid NOT NULL REFERENCES core.branches(id),
  name        text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 60),
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  weekdays    smallint NOT NULL CHECK (weekdays BETWEEN 1 AND 127),  -- bit mask: Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64
  break_start time,
  break_end   time,
  active      boolean NOT NULL DEFAULT true,
  created_by  uuid NOT NULL,                    -- identity.users.id (no FK: another service)
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  version     integer NOT NULL DEFAULT 0,
  CHECK (start_time <> end_time),
  CHECK ((break_start IS NULL) = (break_end IS NULL)),
  CHECK (break_start IS NULL OR break_start <> break_end),
  UNIQUE (branch_id, name)
);
CREATE INDEX idx_shifts_branch ON core.shifts (branch_id) WHERE active;

-- Floor Managers on a shift. The user must hold an ACTIVE BRANCH_MANAGER membership for the branch (checked through auth-service).
CREATE TABLE core.shift_managers (
  shift_id   uuid NOT NULL REFERENCES core.shifts(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL,
  tenant_id  uuid NOT NULL REFERENCES core.tenants(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (shift_id, user_id)
);
CREATE INDEX idx_shift_managers_user ON core.shift_managers (user_id);

-- Written at the end of a shift; never edited (a correction is a new note). Acknowledged once by the next person.
CREATE TABLE core.handover_notes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
  branch_id       uuid NOT NULL REFERENCES core.branches(id),
  shift_id        uuid REFERENCES core.shifts(id),
  summary         text NOT NULL CHECK (char_length(summary) BETWEEN 1 AND 4000),
  pending_tasks   text NOT NULL DEFAULT '' CHECK (char_length(pending_tasks) <= 4000),
  incidents       text NOT NULL DEFAULT '' CHECK (char_length(incidents) <= 4000),
  cash_notes      text NOT NULL DEFAULT '' CHECK (char_length(cash_notes) <= 2000),
  priority        text NOT NULL DEFAULT 'INFO' CHECK (priority IN ('INFO','ATTENTION','URGENT')),
  author_id       uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  acknowledged_by uuid,
  acknowledged_at timestamptz,
  CHECK ((acknowledged_by IS NULL) = (acknowledged_at IS NULL))
);
CREATE INDEX idx_handover_branch ON core.handover_notes (branch_id, created_at DESC);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['shifts','shift_managers','handover_notes'] LOOP
    EXECUTE format('ALTER TABLE core.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY p_tenant_api   ON core.%I TO app_api USING (tenant_id::text = current_setting(''app.tenant_id'', true)) WITH CHECK (tenant_id::text = current_setting(''app.tenant_id'', true))', t);
    EXECUTE format('CREATE POLICY p_platform_api ON core.%I TO app_api USING (current_setting(''app.platform_scope'', true) = ''on'') WITH CHECK (current_setting(''app.platform_scope'', true) = ''on'')', t);
    EXECUTE format('CREATE POLICY p_worker_all   ON core.%I TO app_worker USING (true) WITH CHECK (true)', t);
    EXECUTE format('CREATE POLICY p_readonly_all ON core.%I FOR SELECT TO app_readonly USING (true)', t);
  END LOOP;
END $$;
GRANT SELECT ON core.shifts, core.shift_managers, core.handover_notes TO app_readonly;

COMMIT;

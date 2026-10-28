-- 000007 Issue reporting (decisions 2026-10-12): cafe staff report problems with a seat, machine, game, payment, Horizon client or billing;
-- the cafe's owner/managers follow them; InstaGPU support and platform admins see issues across all cafes.
BEGIN;

CREATE TABLE core.issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  branch_id uuid REFERENCES core.branches(id),
  category text NOT NULL CHECK (category IN ('SEAT','MACHINE','GAME','PAYMENT','HORIZON_CLIENT','BILLING')),
  severity text NOT NULL DEFAULT 'MEDIUM' CHECK (severity IN ('LOW','MEDIUM','HIGH')),
  status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED')),
  title text NOT NULL CHECK (length(title) BETWEEN 3 AND 200),
  description text NOT NULL DEFAULT '' CHECK (length(description) <= 4000),
  seat_id uuid REFERENCES core.seats(id),
  session_id uuid REFERENCES gaming.sessions(id),
  invoice_id uuid REFERENCES billing.invoices(id),
  reported_by uuid NOT NULL REFERENCES identity.users(id),
  assigned_to uuid REFERENCES identity.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  version integer NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX uq_issues_number ON core.issues(number);
CREATE INDEX idx_issues_tenant_status ON core.issues(tenant_id, status, created_at DESC);
CREATE INDEX idx_issues_branch ON core.issues(branch_id) WHERE branch_id IS NOT NULL;

CREATE TABLE core.issue_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id uuid NOT NULL REFERENCES core.issues(id),
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  author_id uuid NOT NULL REFERENCES identity.users(id),
  kind text NOT NULL DEFAULT 'COMMENT' CHECK (kind IN ('COMMENT','STATUS','ASSIGNMENT','SEVERITY')),
  body text NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_issue_comments_issue ON core.issue_comments(issue_id, created_at);

GRANT SELECT, INSERT, UPDATE ON core.issues TO app_api, app_worker;
GRANT SELECT, INSERT ON core.issue_comments TO app_api, app_worker;
GRANT SELECT ON core.issues, core.issue_comments TO app_readonly;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['issues','issue_comments'] LOOP
    EXECUTE format('ALTER TABLE core.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY p_tenant_api   ON core.%I TO app_api USING (tenant_id::text = current_setting(''app.tenant_id'', true)) WITH CHECK (tenant_id::text = current_setting(''app.tenant_id'', true))', t);
    EXECUTE format('CREATE POLICY p_platform_api ON core.%I TO app_api USING (current_setting(''app.platform_scope'', true) = ''on'') WITH CHECK (current_setting(''app.platform_scope'', true) = ''on'')', t);
    EXECUTE format('CREATE POLICY p_worker_all   ON core.%I TO app_worker USING (true) WITH CHECK (true)', t);
    EXECUTE format('CREATE POLICY p_readonly_all ON core.%I FOR SELECT TO app_readonly USING (true)', t);
  END LOOP;
END $$;

COMMIT;

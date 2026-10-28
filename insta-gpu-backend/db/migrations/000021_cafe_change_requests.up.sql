-- 000021 cafe-management-service (docs/database-design.md §3.2): who onboarded a cafe, the owner's logo, branch versioning, and the
-- Super Admin's approval queue (core.change_requests).
-- Rules (CLAUDE.md): a new branch starts PENDING (no sessions) with a NEW_BRANCH request; a Sales Manager's edit is an EDIT_* request
-- and the live row stays unchanged until approved; an owner's edit applies at once; rejection needs feedback; resubmitting = new request.
BEGIN;

-- The Sales Manager (Keycloak role admin) who created the cafe. Display filter only ("my cafes"); staff still see every cafe (ADR-014).
-- No FK: identity belongs to auth-service.
ALTER TABLE core.tenants ADD COLUMN onboarded_by uuid;
CREATE INDEX idx_tenants_onboarded_by ON core.tenants (onboarded_by) WHERE onboarded_by IS NOT NULL;

ALTER TABLE core.branches
  ADD COLUMN version integer NOT NULL DEFAULT 0,
  ADD COLUMN created_by uuid;

-- Owner logo (frontend profile, statements). A small image in the DB, like identity.user_avatars.
CREATE TABLE core.tenant_logos (
  tenant_id    uuid PRIMARY KEY REFERENCES core.tenants(id),
  content_type text NOT NULL CHECK (content_type IN ('image/png','image/jpeg','image/webp')),
  data         bytea NOT NULL CHECK (octet_length(data) BETWEEN 1 AND 262144),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.change_requests (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES core.tenants(id),
  branch_id    uuid REFERENCES core.branches(id),
  kind         text NOT NULL CHECK (kind IN ('NEW_TENANT','NEW_BRANCH','EDIT_TENANT','EDIT_BRANCH')),
  status       text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','WITHDRAWN')),
  proposed     jsonb NOT NULL DEFAULT '{}'::jsonb,  -- fields to set when approved (EDIT_*); empty for NEW_*
  snapshot     jsonb NOT NULL DEFAULT '{}'::jsonb,  -- live values when submitted, for the diff view
  requested_by uuid NOT NULL,                      -- identity.users.id (no FK: another service)
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_by   uuid,
  decided_at   timestamptz,
  feedback     text CHECK (feedback IS NULL OR char_length(feedback) <= 2000),
  version      integer NOT NULL DEFAULT 0,
  CHECK ((kind IN ('NEW_BRANCH','EDIT_BRANCH')) = (branch_id IS NOT NULL)),
  CHECK (kind NOT IN ('EDIT_TENANT','EDIT_BRANCH') OR proposed <> '{}'::jsonb),
  CHECK (status <> 'REJECTED' OR (feedback IS NOT NULL AND char_length(feedback) >= 5)),  -- IS NOT NULL: a NULL check passes
  CHECK ((status IN ('APPROVED','REJECTED')) = (decided_at IS NOT NULL AND decided_by IS NOT NULL))
);
-- One open request per cafe / branch.
CREATE UNIQUE INDEX uq_change_request_open ON core.change_requests (coalesce(branch_id, tenant_id)) WHERE status = 'PENDING';
CREATE INDEX idx_change_requests_queue ON core.change_requests (status, requested_at);
CREATE INDEX idx_change_requests_tenant ON core.change_requests (tenant_id, requested_at DESC);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['change_requests','tenant_logos'] LOOP
    EXECUTE format('ALTER TABLE core.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY p_tenant_api   ON core.%I TO app_api USING (tenant_id::text = current_setting(''app.tenant_id'', true)) WITH CHECK (tenant_id::text = current_setting(''app.tenant_id'', true))', t);
    EXECUTE format('CREATE POLICY p_platform_api ON core.%I TO app_api USING (current_setting(''app.platform_scope'', true) = ''on'') WITH CHECK (current_setting(''app.platform_scope'', true) = ''on'')', t);
    EXECUTE format('CREATE POLICY p_worker_all   ON core.%I TO app_worker USING (true) WITH CHECK (true)', t);
    EXECUTE format('CREATE POLICY p_readonly_all ON core.%I FOR SELECT TO app_readonly USING (true)', t);
  END LOOP;
END $$;
GRANT SELECT ON core.change_requests, core.tenant_logos TO app_readonly;

COMMIT;

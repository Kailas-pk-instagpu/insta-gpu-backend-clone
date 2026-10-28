-- 000020 auth-service (docs/database-design.md §3.1): who created a login, the in-app notification inbox, account-deletion requests,
-- and one ACTIVE membership per person, cafe, role and branch (the old UNIQUE treated a NULL branch_id as distinct, so owners could repeat).
-- identity tables have no RLS (as in the reference): auth-service filters by user and checks scope in code.
BEGIN;

-- The person who created this login (Super Admin -> Sales Manager -> Cafe Owner -> Floor Manager). NULL for seeded / first-login users.
ALTER TABLE identity.users ADD COLUMN created_by uuid REFERENCES identity.users(id);

CREATE UNIQUE INDEX uq_membership_active ON core.tenant_memberships
  (tenant_id, user_id, role, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) WHERE status = 'ACTIVE';
CREATE INDEX idx_membership_user ON core.tenant_memberships (user_id) WHERE status = 'ACTIVE';

-- In-app notifications, one row per recipient. Other services create them through auth-service (POST /internal/notifications).
CREATE TABLE identity.notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES identity.users(id),
  tenant_id  uuid,                                  -- cafe it is about, if any (no FK: core belongs to another service)
  type       text NOT NULL CHECK (type ~ '^[a-z][a-z0-9_.]{1,63}$'),   -- e.g. branch.approved, statement.due
  title      text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  body       text NOT NULL DEFAULT '' CHECK (char_length(body) <= 2000),
  link       text CHECK (link IS NULL OR char_length(link) <= 500),  -- path in the frontend, e.g. /approvals
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_inbox ON identity.notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON identity.notifications (user_id) WHERE read_at IS NULL;

-- A request to close someone's account (their own or a person below them). Approving disables the login and blanks personal fields;
-- the row and the user's history stay (no hard delete).
CREATE TABLE identity.account_deletion_requests (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id  uuid NOT NULL REFERENCES identity.users(id),
  requested_by    uuid NOT NULL REFERENCES identity.users(id),
  reason          text NOT NULL CHECK (char_length(reason) BETWEEN 5 AND 1000),
  status          text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  resolved_by     uuid REFERENCES identity.users(id),
  resolved_at     timestamptz,
  resolution_note text CHECK (resolution_note IS NULL OR char_length(resolution_note) <= 1000),
  CHECK ((status = 'PENDING') = (resolved_at IS NULL AND resolved_by IS NULL))
);
CREATE UNIQUE INDEX uq_deletion_request_pending ON identity.account_deletion_requests (target_user_id) WHERE status = 'PENDING';
CREATE INDEX idx_deletion_requests_status ON identity.account_deletion_requests (status, created_at DESC);

GRANT SELECT ON identity.notifications, identity.account_deletion_requests TO app_readonly;

COMMIT;

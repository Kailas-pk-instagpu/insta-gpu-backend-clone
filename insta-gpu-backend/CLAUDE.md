# InstaGPU backend: working rules for AI assistants (and people)

InstaGPU manages cloud-GPU gaming cafes: owners, branches, seats, gaming sessions on Omnissa Horizon 8,
daily billing and DuitNow QR payments through HitPay. Frontend: React (Vite), talks only to `bff-service`.

## Where we are
- Scaffold only: six NestJS 11 services, each with `GET /healthz` and `GET /readyz` from `libs/shared-http`.
- Folder structure is complete: every feature module has empty `*.module.ts`, `*.controller.ts` (no routes),
  `*.service.ts` and `*.repository.ts`, all registered in each service's `app.module.ts` after `HealthModule`,
  along with `clients/`, `jobs/` and `internal/` modules where a service has them. The `libs/*/src` files are named
  placeholders (empty classes or `export {}`). There is no business logic, database code or auth yet.
- `pnpm install`, `pnpm build`, `pnpm typecheck`, `pnpm start` and `pnpm check:health` all pass.
  `docker compose -f infra/docker-compose.yml up --build` builds all six images, and every container reports healthy.
- Windows: `corepack enable` needs admin rights to write into `C:\Program Files\nodejs`. Without admin, run
  `corepack enable --install-directory <a user folder>` and put that folder on PATH.
- Auth port from InstaGPU-GC-Core (staged; reference copy: `C:\Users\Admin\Desktop\InstGPU\InstaGPU-GC-Core`):
  - Stage 1 done (2026-10-28): local stack and database. `docker compose --env-file .env -f infra/docker-compose.yml up --build`
    starts Postgres 18 (host port 5433), `migrate` (golang-migrate, `db/migrations` 000001-000019 copied unchanged),
    `db-roles` (`db/roles`: one NOLOGIN group role + one `app_<x>_login` per service, own-schema grants, and the
    reference's `app_api` RLS policies mirrored per service role), Keycloak 26.4 (realm `instagpu`, clients `instagpu-bff`,
    `svc-<service>` with audience `instagpu-internal`, `svc-user-provisioner`, the six dev users), Kong 3.9.1
    (`infra/kong/kong.yaml`: `/api/v1/*` path routes per service, rate limit per `x-bff-session`, correlation id,
    security headers; health and `/internal` not routed). ADR-005/010/013 copied to `docs/adr`.
  - Roles: only the frontend's four (ADR-014): `super_admin`, `admin` (= Sales Manager), `cafe_owner`, `manager`
    (= Floor Manager). Dev users: farah (super_admin), sara.tan (admin), jason (cafe_owner), priya (manager).
    When porting reference code, rename platform_admin/sales_manager/branch_manager accordingly; drop finance/support/floor_staff.
    Platform staff (see every cafe) = `super_admin` and `admin`; `cafe_owner` / `manager` are limited by membership.
  - Stage 2, database part done (2026-10-28): `libs/shared-db` ports the reference `db.ts` (`getDb`, `withTx` with
    `app.tenant_id` / `app.platform_scope` / `app.correlation_id` SET LOCAL, `withAdvisoryLock`) plus `pingDb` and
    `DbModule.forService(name)`. All six services import it and connect with their own `app_<x>_login` (`DATABASE_URL`;
    compose sets it, locally copy `services/<x>/.env.example` to `.env`, read by `pnpm start`). `/readyz` runs the
    database check (503 when PostgreSQL is down; `/healthz` stays 200). The pool handles dropped idle connections (a
    database restart used to crash every service). `pnpm test:db` runs the RLS tests against the compose database.
  - Database design accepted (2026-10-28): `docs/database-design.md` (table ownership per service, frontend mapping, decisions
    D1–D4: owner billing only, rate per owner per hour, cafe = tenant, GPU nodes latest metrics only). Migrations 000020–000025 add
    notifications, account-deletion requests, change requests (approvals), tenant logos, shifts, handover notes, wider issue categories,
    `invoice_lines.branch_id` and `integration.gpu_nodes`. Our 000020+ are NOT the reference's 000020 (e-invoice fields, not ported).
  - End-to-end login works with the frontend (2026-10-28), verified in a browser: React (`cloud-game-ops-main`, Vite :8080, proxies
    `/bff` to :3000) -> bff-service -> Keycloak (code + PKCE) -> back with an HttpOnly `igpu_sid` + readable `igpu_csrf` cookie;
    `/bff/api/v1/*` -> Kong -> auth-service `GET /api/v1/me`. Logout ends the BFF and Keycloak sessions. Refresh under a row lock.
    - libs: `shared-config` (zod `loadConfig`), `shared-http` (ApiError + error envelope filter, correlation id, logger),
      `shared-auth` (global `JwtAuthGuard` via `AuthModule.forService`, `@Public`, `@Roles`, `@CurrentUser`, principal with the four
      roles + inheritance, scope helpers returning 404). Health controller is public.
    - auth-service: `UsersService` resolves the principal from the DB (first-login upsert by Keycloak sub, memberships via
      `core.active_memberships_of`); `GET /api/v1/me`. Only auth-service uses `AuthModule` so far.
    - bff-service (no global prefix): `/bff/auth/login|callback|logout`, `SessionGuard`, `CsrfGuard`, proxy to Kong. Reads Keycloak
      metadata from `OIDC_INTERNAL_URL` and points server-to-server endpoints there (issuer stays `localhost:8081`).
    - Frontend (not a git repo; backup of the original in the session scratchpad): `src/shared/lib/bff.ts`, store `loadSession` /
      `beginLogin` / BFF logout, login page redirects to Keycloak, `DashboardLayout` loads the session, change password goes to
      Keycloak, Vite `/bff` proxy. `VITE_AUTH_MODE=mock` brings back the old demo logins.
  - Keycloak login themes (`infra/keycloak/themes`): `instagpu` = the production look, styled like the frontend (GPU Cloud brand,
    Inter, navy + indigo/violet, light mode = the frontend's light palette); `instagpu-dev` = `instagpu` + the "Sign in as" picker
    (holds the dev password, DEV ONLY). The dev realm uses `instagpu-dev`; a real realm must set `"loginTheme": "instagpu"` and not
    mount `instagpu-dev`. Theme changes show on reload (start-dev, no cache); a new theme folder needs a Keycloak restart.
  - Running apps on the host (used while Docker could not pull `node:22-alpine`): `infra/docker-compose.host-apps.yml` points Kong at
    the host; copy each `services/<x>/.env.example` to `.env`, then `pnpm build && pnpm start`.
  - Not done yet: InternalAuthGuard + `/internal/principals/:sub` + the other services' guards (Stage 5), users / memberships APIs,
    idempotency, audit (Stage 3), dev seed data (the dev users have no cafe memberships yet).
  - Next: rest of Stage 2: `libs/shared-config`, `shared-http` (error envelope, correlation id, Idempotency-Key),
    `shared-auth` (guards, principal, scope).
- `pnpm test` runs each package's `test` script (none yet). Without pnpm on PATH: `corepack pnpm <cmd>` works for
  top-level commands, but nested `pnpm -r` needs the corepack shim on PATH (see the Windows note above).

## Services and ports
All services live under `services/<name>-service/`; shared code under `libs/`.

| Service | Port | Owns (database schema) |
|---|---|---|
| bff-service | 3000 | `identity.bff_sessions` |
| auth-service | 3001 | `identity`, memberships |
| cafe-management-service | 3002 | `core` (owners, branches, approvals, seats, issues) |
| session-service | 3003 | `gaming` (sessions, floor, dashboard) |
| billing-service | 3004 | `billing`, `commercial`, `payments`, `ledger` |
| integration-service | 3005 | `integration` (Horizon) |

## Architecture rules (do not change without an ADR in docs/adr)
- All backend code is NestJS (TypeScript, Node 22). No Python, no RabbitMQ, no Redis for now.
- Services call each other with plain HTTP on `/internal/...`, never through Kong. Every call: timeout, retry,
  service token, `Idempotency-Key`, correlation id. Receiving endpoints must be safe to repeat.
- A service writes only its own schema; it asks other services for anything else.
- Shared code lives in `libs/` (`@instagpu/*`), never copied into a service.
- Every feature module has: `*.controller.ts`, `*.service.ts`, `*.repository.ts`, `*.module.ts`, `dto/`. SQL only in repositories.
- Business routes under `/api/v1`; health checks stay at `/healthz` and `/readyz`.
- Scheduled jobs take a PostgreSQL advisory lock so several copies of a service are safe.
- Reference implementation to port from: the InstaGPU-GC-Core repo (auth guard, scope, idempotency, Horizon client,
  HitPay provider, billing rules, golang-migrate migrations 000001-000019).

## Business rules to keep
- Sales Manager creates the cafe owner first, then branches under that owner. A new branch starts DISABLED and needs
  Super Admin approval; rejection needs feedback; Sales Manager edits need re-approval (old values stay live); owner edits do not.
- Billing is per owner, daily, postpaid. Unpaid statement => payment hold (no new sessions, running ones continue).
- Payments: HitPay DuitNow QR only, no cash. Webhook: verify signature on the raw body, store once, confirm with HitPay, apply once;
  the payment and its ledger entry commit in one transaction.
- Money is integer sen (never floats). Times stored UTC; business day = Asia/Kuala_Lumpur.

## Commands
pnpm install · pnpm build · pnpm test · pnpm test:db (needs the compose stack) · pnpm start · pnpm dev · pnpm check:health · pnpm typecheck
Local stack: `docker compose --env-file .env -f infra/docker-compose.yml up --build` (Keycloak :8081, Kong :8000, Postgres :5433)

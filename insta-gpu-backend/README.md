# insta-gpu-backend

InstaGPU backend: six NestJS 11 microservices in one pnpm workspace, sharing code from `libs/`.
Right now every service only has its health endpoints; features are added module by module.

| Service | Port | Purpose |
|---|---|---|
| `bff-service` | 3000 | Backend-for-frontend: Keycloak login, cookie sessions, /bff/api proxy to Kong |
| `auth-service` | 3001 | People, roles, memberships, own profile, Keycloak admin |
| `cafe-management-service` | 3002 | Owners, branches (with approvals), seats, issues |
| `session-service` | 3003 | Sessions, live floor, dashboard, capacity, account standing, agents |
| `billing-service` | 3004 | Nightly billing, statements, payment hold, HitPay payments, notifications |
| `integration-service` | 3005 | Horizon 8 poller and status (only holder of Horizon credentials) |

Every service answers `GET /healthz` (alive) and `GET /readyz` (ready for traffic). Business routes will live under `/api/v1`
(the BFF uses `/auth/...` and `/bff/api/...`).

## Requirements
- Node.js 22 (`.nvmrc`)
- pnpm 10: `corepack enable` (pnpm comes with Node through corepack)

## Run
```bash
pnpm install          # installs every service and lib
pnpm build            # builds libs first, then services
pnpm start            # starts all six services (built code)
pnpm check:health     # in another terminal: calls /healthz on all six
```
Development with reload: `pnpm dev`. One service only: `pnpm --filter @instagpu/session-service start:dev`.

Docker: `docker compose -f infra/docker-compose.yml up --build` (from the repository root).

## Layout
```
services/<name>-service/
  src/
    main.ts            bootstrap: port, /api/v1 prefix, graceful shutdown
    app.module.ts      imports HealthModule + feature modules
    modules/<feature>/ controller, service, repository, module, dto/   (empty for now)
    clients/           HTTP clients to other services (later)
    internal/          /internal endpoints other services call (later)
    jobs/              scheduled jobs (later)
  test/
  Dockerfile  package.json  nest-cli.json  tsconfig*.json  .env.example
libs/                  shared code (@instagpu/shared-http has the health module)
db/                    migrations (golang-migrate), roles, seed
infra/                 docker-compose, kong, keycloak
docs/                  adr, runbooks, api
scripts/               check-health.mjs
```

## Rules
- A service writes only its own database schema; it asks other services over HTTP (`/internal/...`).
- Shared code goes in `libs/`, never copied into a service.
- Each feature module has the same parts: controller, service, repository, module, dto/.

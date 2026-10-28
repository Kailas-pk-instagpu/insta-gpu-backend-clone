# ADR-014 Four roles, named as in the frontend
Status: Accepted · Date: 2026-10-28 · Supersedes the role catalogue of ADR-010 and ADR-013 (copied from InstaGPU-GC-Core)

## Context
The reference (InstaGPU-GC-Core) has eight realm roles. The frontend (React, `cloud-game-ops`, `src/shared/types/auth.ts`)
has four, and the product owner wants only those.

## Decision
Keycloak realm roles (and groups of the same name), `@Roles()` values and `/me` use the frontend keys:

| Role key | Label in the UI | Reference role it replaces |
|---|---|---|
| `super_admin` | Super Admin | `platform_admin` |
| `admin` | Sales Manager | `sales_manager` |
| `cafe_owner` | Cafe Owner | `cafe_owner` |
| `manager` | Floor Manager | `branch_manager` |

`finance_admin`, `finance_viewer`, `support_admin` and `floor_staff` are dropped.

Inheritance keeps the reference rule (a route lists the lowest role allowed; expanded once when the principal is built):
`super_admin` ⊃ `admin`, `cafe_owner`, `manager`; `cafe_owner` ⊃ `manager`. Inheritance never widens scope: cafe roles are
still limited by `core.tenant_memberships`.

Memberships keep the reference table and its CHECK constraint (migrations are unchanged): `cafe_owner` -> membership role
`CAFE_OWNER`, `manager` -> `BRANCH_MANAGER` (one row per assigned branch). `FLOOR_STAFF` and `FINANCE_VIEWER` are not used.

## Consequences
+ The frontend uses `/me` roles directly, no mapping.
− Ported code, helpers and tests are renamed from the reference names. `admin` means Sales Manager, not super admin.

## Scope of the Sales Manager (decided 2026-10-28, product owner)
`admin` (Sales Manager) sees **every cafe**, as the reference's `sales_manager` does: it is platform staff (`tenantScope` = `*`,
RLS `app.platform_scope = on` after the role check). What it may DO is still decided per route (`@Roles`) and in services.
The frontend's narrower list (cafes with `adminId` = me) is a UI filter only, not an access rule.
Platform staff = `super_admin` and `admin`; cafe roles (`cafe_owner`, `manager`) are limited by membership.

# ADR-010 — Role inheritance and InstaGPU support access

Status: accepted 2026-10-12 (product owner). Refines spec §28 (role catalogue) for V1.

## Decision
- Roles inherit downward so that when someone cannot do something, the person above them can:
  `floor_staff` ⊂ `branch_manager` ⊂ `cafe_owner` ⊂ `platform_admin`; `finance_viewer` ⊂ `finance_admin` ⊂ `platform_admin`; `support_admin` ⊂ `platform_admin`.
  A route lists the lowest role allowed to use it; `impliedRoles()` (`shared/auth/principal.ts`) expands a person's roles once, when the principal is built.
- Cafe roles stay limited by their membership: a manager of branch A has staff rights in branch A only; an owner has them across their own cafe only. Inheritance never widens scope.
- `support_admin` is InstaGPU staff that sees **every cafe** (assigning support staff to specific cafes is a later, P4/P5 item) and may read issues, sessions and users and create users, but sees **no money** (`canViewMoney` is false for support).
- Platform admin (super admin) can do and see everything support and finance can.
- Who creates users: cafe owner (own cafe, all branches), platform admin and support admin (e.g. when an owner asks).

## Consequences
- `GET /me` returns the **effective** roles (an owner also lists branch_manager and floor_staff).
- Tests: `principal.test.ts` (inheritance, money visibility) and `roles.int.test.ts` (through the real API).
- Keycloak keeps only the coarse realm role; tenant/branch scope still comes from `core.tenant_memberships`.

# ADR-013 Sales manager role
Status: Accepted · Date: 2026-10-19

## Context
Onboarding a cafe (creating it, its company details, billing terms, branches and the owner's login) and following up its account (who owes
what, pausing a branch, a short extension after a promise to pay) was possible only for the super admin. A sales person needs these, and only these.

## Decision
New Keycloak realm role and group `sales_manager` (InstaGPU staff, sees every cafe). The platform admin inherits it.

| Sales may | Sales may not |
|---|---|
| create a cafe with its terms (`POST /tenants`) | record payments, credit notes, voids, missed usage (finance) |
| edit company details, onboarding facts, billing terms incl. discounts | run billing, record provider outages (finance) |
| add branches; **suspend / re-activate a branch** (new `PUT /branches/{id}/status`, reason required, owners e-mailed) | add seats or change them (owner / admin, with the platform team) |
| create the cafe **owner's** login only (the owner adds their team) | create managers, staff, finance viewers or InstaGPU staff; disable logins |
| see money read-only: statements, balances, ageing, revenue, payments, hold history, usage, spending | pay a statement; change the desktop pool size; see sign-ins; use the simulator |
| lift a payment hold for up to 14 days with a reason | start or end sessions, bookings, issues |

Branch suspension is manual and per branch; the automatic payment hold (whole cafe, ADR-003) is unchanged. Console: a **Cafes** page
(account list with owners, branches, rate, outstanding / overdue, and the actions above). Enforced at the API (`@Roles` + service checks),
documented in the OpenAPI contract (`x-roles`, checked by `openapi-coverage.test.ts`), tested in `sales-role.int.test.ts`.

## Consequences
+ Sales can onboard and look after accounts without super-admin rights. Every action is audited.
− Sales can set discounts without a second approval (audited). If needed later: a maximum discount or a finance approval step.

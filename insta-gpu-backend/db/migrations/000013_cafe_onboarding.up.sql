-- 000013 Cafe onboarding attributes (meeting 2026-10): credit extension period per cafe, VDAs procured, and the Active Directory group of the cafe.
BEGIN;
ALTER TABLE commercial.commercial_accounts
  ADD COLUMN hold_grace_days integer NOT NULL DEFAULT 0 CHECK (hold_grace_days BETWEEN 0 AND 30);   -- extra days after the due moment before new sessions pause
ALTER TABLE core.tenants
  ADD COLUMN vdas_procured integer CHECK (vdas_procured IS NULL OR vdas_procured BETWEEN 0 AND 5000),
  ADD COLUMN ad_group text CHECK (ad_group IS NULL OR length(ad_group) BETWEEN 2 AND 64);              -- AD group whose members are entitled to the Horizon pool for this cafe
CREATE UNIQUE INDEX uq_tenants_ad_group ON core.tenants (lower(ad_group)) WHERE ad_group IS NOT NULL;
GRANT UPDATE (vdas_procured, ad_group, updated_at) ON core.tenants TO app_api;
COMMIT;

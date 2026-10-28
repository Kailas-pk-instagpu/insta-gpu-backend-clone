-- 000023 cafe-management-service: the frontend's issue categories (GPU, PC, network, peripheral, software, other) and CRITICAL severity.
-- Existing values stay valid.
BEGIN;
ALTER TABLE core.issues DROP CONSTRAINT issues_category_check;
ALTER TABLE core.issues ADD CONSTRAINT issues_category_check CHECK (category IN
  ('SEAT','MACHINE','GAME','PAYMENT','HORIZON_CLIENT','BILLING','GPU','PC','NETWORK','PERIPHERAL','SOFTWARE','OTHER'));
ALTER TABLE core.issues DROP CONSTRAINT issues_severity_check;
ALTER TABLE core.issues ADD CONSTRAINT issues_severity_check CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL'));
COMMIT;

-- Maps the new values back onto the old ones so the narrower checks can be restored (lossy: GPU/PC -> MACHINE, others -> SEAT,
-- CRITICAL -> HIGH).
BEGIN;
UPDATE core.issues SET category = 'MACHINE' WHERE category IN ('GPU','PC');
UPDATE core.issues SET category = 'SEAT' WHERE category IN ('NETWORK','PERIPHERAL','SOFTWARE','OTHER');
UPDATE core.issues SET severity = 'HIGH' WHERE severity = 'CRITICAL';
ALTER TABLE core.issues DROP CONSTRAINT issues_category_check;
ALTER TABLE core.issues ADD CONSTRAINT issues_category_check CHECK (category IN ('SEAT','MACHINE','GAME','PAYMENT','HORIZON_CLIENT','BILLING'));
ALTER TABLE core.issues DROP CONSTRAINT issues_severity_check;
ALTER TABLE core.issues ADD CONSTRAINT issues_severity_check CHECK (severity IN ('LOW','MEDIUM','HIGH'));
COMMIT;

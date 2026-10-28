BEGIN;
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT schemaname, tablename, policyname FROM pg_policies
           WHERE policyname IN ('p_tenant_api','p_worker_all','p_readonly_all','p_platform_api') LOOP
    EXECUTE format('DROP POLICY %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;
COMMIT;

-- 000025 integration-service: physical GPU hosts for the Super Admin's GPU Nodes page, with their LATEST metrics only (D4: no history
-- until the metrics source is chosen). Platform data, not per cafe: no tenant_id, no RLS; only platform staff routes read it.
BEGIN;

CREATE TABLE integration.gpu_nodes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text NOT NULL UNIQUE CHECK (char_length(name) BETWEEN 2 AND 80),
  branch_id           uuid,                         -- where it serves, if dedicated (no FK: core belongs to another service)
  location            text CHECK (location IS NULL OR char_length(location) <= 120),
  gpu_model           text NOT NULL CHECK (char_length(gpu_model) BETWEEN 2 AND 60),
  serial_number       text CHECK (serial_number IS NULL OR char_length(serial_number) <= 80),
  ip_address          inet,
  driver_version      text CHECK (driver_version IS NULL OR char_length(driver_version) <= 40),
  cuda_version        text CHECK (cuda_version IS NULL OR char_length(cuda_version) <= 40),
  vbios_version       text CHECK (vbios_version IS NULL OR char_length(vbios_version) <= 40),
  installed_at        timestamptz,
  last_maintenance_at timestamptz,
  status              text NOT NULL DEFAULT 'OFFLINE' CHECK (status IN ('ONLINE','OFFLINE','WARNING','MAINTENANCE','OVERLOADED')),
  health              text NOT NULL DEFAULT 'HEALTHY' CHECK (health IN ('HEALTHY','DEGRADED','CRITICAL')),
  -- latest metrics (NULL until the first report)
  temperature_c       smallint CHECK (temperature_c IS NULL OR temperature_c BETWEEN -20 AND 150),
  utilization_pct     smallint CHECK (utilization_pct IS NULL OR utilization_pct BETWEEN 0 AND 100),
  memory_used_mb      integer CHECK (memory_used_mb IS NULL OR memory_used_mb >= 0),
  memory_total_mb     integer CHECK (memory_total_mb IS NULL OR memory_total_mb > 0),
  power_w             integer CHECK (power_w IS NULL OR power_w >= 0),
  fan_pct             smallint CHECK (fan_pct IS NULL OR fan_pct BETWEEN 0 AND 100),
  clock_mhz           integer CHECK (clock_mhz IS NULL OR clock_mhz >= 0),
  memory_clock_mhz    integer CHECK (memory_clock_mhz IS NULL OR memory_clock_mhz >= 0),
  metrics_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  version             integer NOT NULL DEFAULT 0,
  CHECK (memory_used_mb IS NULL OR memory_total_mb IS NULL OR memory_used_mb <= memory_total_mb)
);
CREATE UNIQUE INDEX uq_gpu_nodes_serial ON integration.gpu_nodes (serial_number) WHERE serial_number IS NOT NULL;
CREATE INDEX idx_gpu_nodes_branch ON integration.gpu_nodes (branch_id) WHERE branch_id IS NOT NULL;

GRANT SELECT ON integration.gpu_nodes TO app_readonly;

COMMIT;

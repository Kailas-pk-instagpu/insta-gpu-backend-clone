-- 000008 Pre-booking (decisions 2026-10-12): cafe staff book a seat; the seat is held until 15 minutes after the booked time; no charge, no-shows are free.
-- machine_hold tracks the optional reservation of a VDI in Horizon (maintenance state), carried out by the infra-adapter when BOOKING_HORIZON_HOLD=on.
BEGIN;

CREATE TABLE gaming.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id uuid NOT NULL REFERENCES core.tenants(id),
  branch_id uuid NOT NULL REFERENCES core.branches(id),
  seat_id uuid NOT NULL REFERENCES core.seats(id),
  starts_at timestamptz NOT NULL,
  hold_until timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'BOOKED' CHECK (status IN ('BOOKED','CHECKED_IN','CANCELLED','NO_SHOW')),
  customer_name text NOT NULL CHECK (length(customer_name) BETWEEN 2 AND 80),
  customer_phone text CHECK (customer_phone IS NULL OR length(customer_phone) BETWEEN 5 AND 30),
  note text CHECK (note IS NULL OR length(note) <= 300),
  created_by uuid NOT NULL REFERENCES identity.users(id),
  session_id uuid REFERENCES gaming.sessions(id),
  cancelled_by uuid REFERENCES identity.users(id),
  cancel_reason text CHECK (cancel_reason IS NULL OR length(cancel_reason) <= 300),
  machine_hold text NOT NULL DEFAULT 'NONE' CHECK (machine_hold IN ('NONE','WANTED','HELD','RELEASE_WANTED','RELEASED','FAILED')),
  held_machine text,
  hold_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version integer NOT NULL DEFAULT 0,
  CHECK (hold_until > starts_at)
);
CREATE UNIQUE INDEX uq_bookings_number ON gaming.bookings(number);
CREATE INDEX idx_bookings_seat_open ON gaming.bookings(seat_id, starts_at) WHERE status = 'BOOKED';
CREATE INDEX idx_bookings_tenant ON gaming.bookings(tenant_id, starts_at DESC);
CREATE INDEX idx_bookings_hold ON gaming.bookings(machine_hold) WHERE machine_hold IN ('WANTED','RELEASE_WANTED');

GRANT SELECT, INSERT, UPDATE ON gaming.bookings TO app_api, app_worker;
GRANT SELECT ON gaming.bookings TO app_adapter, app_readonly;
GRANT UPDATE (machine_hold, held_machine, hold_error, updated_at) ON gaming.bookings TO app_adapter;

ALTER TABLE gaming.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_api   ON gaming.bookings TO app_api USING (tenant_id::text = current_setting('app.tenant_id', true)) WITH CHECK (tenant_id::text = current_setting('app.tenant_id', true));
CREATE POLICY p_platform_api ON gaming.bookings TO app_api USING (current_setting('app.platform_scope', true) = 'on') WITH CHECK (current_setting('app.platform_scope', true) = 'on');
CREATE POLICY p_worker_all   ON gaming.bookings TO app_worker USING (true) WITH CHECK (true);
CREATE POLICY p_adapter_read ON gaming.bookings FOR SELECT TO app_adapter USING (true);
CREATE POLICY p_adapter_hold ON gaming.bookings FOR UPDATE TO app_adapter USING (true) WITH CHECK (true);
CREATE POLICY p_readonly_all ON gaming.bookings FOR SELECT TO app_readonly USING (true);

COMMIT;

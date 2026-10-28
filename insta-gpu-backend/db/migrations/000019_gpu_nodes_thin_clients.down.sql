BEGIN;
REVOKE DELETE ON gaming.game_activity, gaming.agent_status FROM app_worker;
DROP TABLE IF EXISTS gaming.thin_client_events;
DROP TABLE IF EXISTS gaming.thin_clients;
ALTER TABLE core.seats DROP CONSTRAINT IF EXISTS fk_seat_gpu_node_type;
DROP TABLE IF EXISTS core.gpu_node_types;
COMMIT;

SET search_path TO app_core, public;

-- server_payload was a sync-era column intended to store the server's version
-- of a conflicting record. No write path populates it (only client_payload is
-- inserted by BillController). Safe to drop as part of sync-engine cleanup.
ALTER TABLE IF EXISTS app_core.conflict_log
    DROP COLUMN IF EXISTS server_payload;

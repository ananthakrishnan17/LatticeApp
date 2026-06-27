SET search_path TO app_core, public;

-- snapshot_json was used only for one-time V19 backfill and is no longer read.
ALTER TABLE IF EXISTS app_core.bills
    DROP COLUMN IF EXISTS snapshot_json;

-- Snapshot payload columns are legacy sync-era artifacts and unused.
ALTER TABLE IF EXISTS app_core.bill_modification_history
    DROP COLUMN IF EXISTS previous_snapshot_json,
    DROP COLUMN IF EXISTS updated_snapshot_json;

-- Idempotency key store is no longer used after sync-engine removal.
DROP TABLE IF EXISTS app_core.idempotency_keys;

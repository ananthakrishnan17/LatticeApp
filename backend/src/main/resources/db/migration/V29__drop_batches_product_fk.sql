-- V29: Drop FK constraint on batches.product_id so that purchases and their batches
-- can be saved before their products are synced to the server (offline-first support).
-- Similar to V28 which dropped the FK on purchase_items.product_id.

ALTER TABLE app_core.batches
    DROP CONSTRAINT IF EXISTS batches_product_id_fkey;

-- V28: Drop FK constraint on purchase_items.product_id so that purchases can be
-- saved before their products are synced to the server (offline-first support).
-- Product name is already stored denormalized in product_name column.

ALTER TABLE app_core.purchase_items
    DROP CONSTRAINT IF EXISTS purchase_items_product_id_fkey;

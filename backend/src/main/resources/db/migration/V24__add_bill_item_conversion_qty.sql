ALTER TABLE app_core.bill_items
    ADD COLUMN IF NOT EXISTS conversion_qty NUMERIC(18,6) NOT NULL DEFAULT 1;

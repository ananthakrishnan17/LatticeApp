-- V19: Normalize bills table – move every scalar field from snapshot_json into
-- proper columns and enrich bill_items with discount / GST detail columns.
--
-- snapshot_json is kept nullable so that any stored receipt snapshot is not
-- destroyed; it will simply stop being written by new code.

-- ─── bills master columns ──────────────────────────────────────────────────────
ALTER TABLE app_core.bills
    ADD COLUMN IF NOT EXISTS bill_type              TEXT            NOT NULL DEFAULT 'retail',
    ADD COLUMN IF NOT EXISTS created_at             TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS total_profit           NUMERIC(14,2)   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cgst_total             NUMERIC(14,2)   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sgst_total             NUMERIC(14,2)   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS igst_total             NUMERIC(14,2)   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS coupon_code            TEXT,
    ADD COLUMN IF NOT EXISTS coupon_discount_amount NUMERIC(14,2)   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cash_tendered          NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS change_amount          NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS customer_address       TEXT,
    ADD COLUMN IF NOT EXISTS customer_gstin         TEXT,
    ADD COLUMN IF NOT EXISTS split_payment_summary  TEXT;

-- Backfill bills from snapshot_json where present
UPDATE app_core.bills
SET
    bill_type              = COALESCE(snapshot_json->>'bill_type', 'retail'),
    total_profit           = COALESCE((snapshot_json->>'total_profit')::NUMERIC, 0),
    cgst_total             = COALESCE((snapshot_json->>'cgst_total')::NUMERIC, 0),
    sgst_total             = COALESCE((snapshot_json->>'sgst_total')::NUMERIC, 0),
    igst_total             = COALESCE((snapshot_json->>'igst_total')::NUMERIC, 0),
    coupon_code            = snapshot_json->>'coupon_code',
    coupon_discount_amount = COALESCE((snapshot_json->>'coupon_discount_amount')::NUMERIC, 0),
    cash_tendered          = NULLIF(snapshot_json->>'cash_tendered', '')::NUMERIC,
    change_amount          = NULLIF(snapshot_json->>'change_amount', '')::NUMERIC,
    customer_address       = snapshot_json->>'customer_address',
    customer_gstin         = snapshot_json->>'customer_gstin',
    split_payment_summary  = snapshot_json->>'split_payment_summary',
    created_at             = COALESCE(
                                 NULLIF(snapshot_json->>'created_at', '')::TIMESTAMPTZ,
                                 updated_at
                             )
WHERE snapshot_json IS NOT NULL;

-- For rows without snapshot_json fall back to updated_at
UPDATE app_core.bills SET created_at = updated_at WHERE created_at IS NULL;

-- ─── bill_items detail columns ─────────────────────────────────────────────────
ALTER TABLE app_core.bill_items
    ADD COLUMN IF NOT EXISTS product_sku         TEXT,
    ADD COLUMN IF NOT EXISTS purchase_price      NUMERIC(14,2)  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gst_rate            NUMERIC(8,4)   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS discount_amount     NUMERIC(14,2)  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS item_discount_type  TEXT           NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS item_discount_value NUMERIC(14,4)  NOT NULL DEFAULT 0;

-- Best-effort backfill bill_items from snapshot_json items array,
-- matched by bill + product_name + quantity (covers the common case).
UPDATE app_core.bill_items bi
SET
    gst_rate             = COALESCE((item_elem->>'gst_rate')::NUMERIC, 0),
    discount_amount      = COALESCE((item_elem->>'discount_amount')::NUMERIC, 0),
    item_discount_type   = COALESCE(item_elem->>'item_discount_type', 'none'),
    item_discount_value  = COALESCE((item_elem->>'item_discount_value')::NUMERIC, 0)
FROM app_core.bills b,
     LATERAL jsonb_array_elements(b.snapshot_json->'items') AS t(item_elem)
WHERE bi.bill_id      = b.server_id
  AND b.snapshot_json IS NOT NULL
  AND (b.snapshot_json->'items') IS NOT NULL
  AND bi.product_name = (item_elem->>'product_name')
  AND bi.quantity     = (item_elem->>'quantity')::NUMERIC;

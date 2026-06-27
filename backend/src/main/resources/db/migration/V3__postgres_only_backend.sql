SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS tenant_licenses (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL UNIQUE REFERENCES tenants(server_id) ON DELETE CASCADE,
    license_key TEXT NOT NULL UNIQUE,
    mobile_number TEXT,
    plan_code TEXT NOT NULL DEFAULT 'basic',
    max_users INTEGER NOT NULL DEFAULT 2,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    activated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS pin_hash TEXT,
    ADD COLUMN IF NOT EXISTS can_bill BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS can_view_reports BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS can_manage_products BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS can_manage_masters BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS can_view_expenses BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS can_manage_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS can_view_dashboard BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE users
SET pin_hash = COALESCE(pin_hash, password_hash)
WHERE pin_hash IS NULL;

ALTER TABLE bills
    ADD COLUMN IF NOT EXISTS bill_type TEXT DEFAULT 'retail',
    ADD COLUMN IF NOT EXISTS customer_address TEXT,
    ADD COLUMN IF NOT EXISTS customer_gstin TEXT,
    ADD COLUMN IF NOT EXISTS total_profit NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS coupon_code TEXT,
    ADD COLUMN IF NOT EXISTS coupon_discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS split_payment_summary TEXT,
    ADD COLUMN IF NOT EXISTS cash_tendered NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS change_amount NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS billed_by_username TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE bill_items
    ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS item_discount_type TEXT DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS item_discount_value NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS product_sku TEXT,
    ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sale_type TEXT DEFAULT 'retail';

ALTER TABLE purchases
    ADD COLUMN IF NOT EXISTS supplier_name TEXT,
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'cash',
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS purchase_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE purchase_items
    ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'piece',
    ADD COLUMN IF NOT EXISTS gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(14,2) NOT NULL DEFAULT 0;

ALTER TABLE sale_returns
    ADD COLUMN IF NOT EXISTS original_bill_number TEXT,
    ADD COLUMN IF NOT EXISTS return_type TEXT DEFAULT 'return',
    ADD COLUMN IF NOT EXISTS customer_name TEXT,
    ADD COLUMN IF NOT EXISTS refund_mode TEXT DEFAULT 'cash',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE expenses
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS is_raw_material BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS erp_transactions (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    tx_type TEXT NOT NULL,
    total_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    tags_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, client_record_id)
);

CREATE INDEX IF NOT EXISTS idx_erp_transactions_tenant_created_at
    ON erp_transactions(tenant_id, created_at DESC);

INSERT INTO tenant_licenses(
    tenant_id,
    license_key,
    mobile_number,
    plan_code,
    max_users,
    is_active,
    activated_at,
    expires_at
)
SELECT
    t.server_id,
    'DEMO-LICENSE-KEY',
    '9999999999',
    'standard',
    6,
    TRUE,
    now(),
    NULL
FROM tenants t
WHERE t.tenant_code = 'demo-tenant'
ON CONFLICT (tenant_id) DO NOTHING;

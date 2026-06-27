-- V6: Add missing columns to purchases/purchase_items/sale_returns/sale_return_items,
--     and create purchase_returns and day_close tables for full transaction tracking

-- purchases: add missing business columns
ALTER TABLE app_core.purchases
    ADD COLUMN IF NOT EXISTS supplier_name TEXT,
    ADD COLUMN IF NOT EXISTS payment_mode TEXT NOT NULL DEFAULT 'cash',
    ADD COLUMN IF NOT EXISTS invoice_number TEXT,
    ADD COLUMN IF NOT EXISTS invoice_amount NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS purchase_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- purchase_items: add unit and GST columns
ALTER TABLE app_core.purchase_items
    ADD COLUMN IF NOT EXISTS unit TEXT NOT NULL DEFAULT 'piece',
    ADD COLUMN IF NOT EXISTS gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(14,2) NOT NULL DEFAULT 0;

-- sale_returns: add original_bill_number (return_type/customer_name/refund_mode/created_at added in V3)
ALTER TABLE app_core.sale_returns
    ADD COLUMN IF NOT EXISTS original_bill_number TEXT;

-- sale_return_items: add unit column
ALTER TABLE app_core.sale_return_items
    ADD COLUMN IF NOT EXISTS unit TEXT NOT NULL DEFAULT 'piece';

CREATE TABLE IF NOT EXISTS app_core.purchase_returns (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES app_core.tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    return_number TEXT NOT NULL,
    original_purchase_number TEXT,
    supplier_name TEXT,
    total_return_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, client_record_id)
);

CREATE INDEX IF NOT EXISTS idx_purchase_returns_tenant_created_at
    ON app_core.purchase_returns(tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS app_core.day_close (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES app_core.tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    close_date DATE NOT NULL,
    cash_opening NUMERIC(14,2) NOT NULL DEFAULT 0,
    cash_closing NUMERIC(14,2) NOT NULL DEFAULT 0,
    cash_variance NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_sales NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_expenses NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_returns NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_purchases NUMERIC(14,2) NOT NULL DEFAULT 0,
    cash_sales NUMERIC(14,2) NOT NULL DEFAULT 0,
    digital_sales NUMERIC(14,2) NOT NULL DEFAULT 0,
    bill_count INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    closed_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, client_record_id)
);

CREATE INDEX IF NOT EXISTS idx_day_close_tenant_close_date
    ON app_core.day_close(tenant_id, close_date DESC);

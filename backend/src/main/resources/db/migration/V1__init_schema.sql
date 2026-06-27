CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS app_core;
SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS tenants (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    username TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'cashier',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, username)
);

CREATE TABLE IF NOT EXISTS devices (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    device_id TEXT NOT NULL,
    display_name TEXT,
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, device_id)
);

CREATE TABLE IF NOT EXISTS categories (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id),
    UNIQUE(tenant_id, name)
);

CREATE TABLE IF NOT EXISTS brands (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id),
    UNIQUE(tenant_id, name)
);

CREATE TABLE IF NOT EXISTS customers (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    gst_number TEXT,
    credit_limit NUMERIC(14,2) NOT NULL DEFAULT 0,
    outstanding_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS suppliers (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    gst_number TEXT,
    outstanding_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS products (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    category_id UUID REFERENCES categories(server_id),
    brand_id UUID REFERENCES brands(server_id),
    name TEXT NOT NULL,
    barcode TEXT,
    hsn_code TEXT,
    item_type TEXT NOT NULL DEFAULT 'physical',
    unit TEXT NOT NULL DEFAULT 'piece',
    purchase_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    selling_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    wholesale_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    stock_quantity NUMERIC(18,3) NOT NULL DEFAULT 0,
    low_stock_threshold NUMERIC(18,3) NOT NULL DEFAULT 0,
    gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id),
    UNIQUE(tenant_id, barcode)
);

CREATE TABLE IF NOT EXISTS product_uoms (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    product_id UUID NOT NULL REFERENCES products(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    uom_name TEXT NOT NULL,
    conversion_qty NUMERIC(18,6) NOT NULL DEFAULT 1,
    selling_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    wholesale_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    purchase_price NUMERIC(14,2) NOT NULL DEFAULT 0,
    unit_role TEXT NOT NULL DEFAULT 'sale',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS bills (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    bill_number TEXT NOT NULL,
    customer_id UUID REFERENCES customers(server_id),
    customer_name TEXT,
    total_amount NUMERIC(14,2) NOT NULL,
    discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    gst_total NUMERIC(14,2) NOT NULL DEFAULT 0,
    payment_mode TEXT NOT NULL DEFAULT 'cash',
    status TEXT NOT NULL DEFAULT 'active',
    snapshot_json JSONB,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id),
    UNIQUE(tenant_id, bill_number)
);

CREATE TABLE IF NOT EXISTS bill_items (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    bill_id UUID NOT NULL REFERENCES bills(server_id) ON DELETE CASCADE,
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    product_id UUID REFERENCES products(server_id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(18,3) NOT NULL,
    unit TEXT NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    total_price NUMERIC(14,2) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS bill_payment_splits (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    bill_id UUID NOT NULL REFERENCES bills(server_id) ON DELETE CASCADE,
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    payment_mode TEXT NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS bill_modification_history (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    bill_id UUID NOT NULL REFERENCES bills(server_id),
    previous_total_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    updated_total_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    modification_note TEXT,
    previous_snapshot_json JSONB,
    updated_snapshot_json JSONB,
    modified_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchases (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    purchase_number TEXT NOT NULL,
    supplier_id UUID REFERENCES suppliers(server_id),
    total_amount NUMERIC(14,2) NOT NULL,
    gst_total NUMERIC(14,2) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS purchase_items (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    purchase_id UUID NOT NULL REFERENCES purchases(server_id) ON DELETE CASCADE,
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    product_id UUID REFERENCES products(server_id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(18,3) NOT NULL,
    unit_cost NUMERIC(14,2) NOT NULL,
    total_cost NUMERIC(14,2) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS expenses (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    amount NUMERIC(14,2) NOT NULL,
    expense_date TIMESTAMPTZ NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS sale_returns (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    return_number TEXT NOT NULL,
    original_bill_id UUID REFERENCES bills(server_id),
    total_return_amount NUMERIC(14,2) NOT NULL,
    reason TEXT,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS sale_return_items (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    return_id UUID NOT NULL REFERENCES sale_returns(server_id) ON DELETE CASCADE,
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    product_id UUID REFERENCES products(server_id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(18,3) NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    total_price NUMERIC(14,2) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS batches (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    product_id UUID NOT NULL REFERENCES products(server_id),
    purchase_id UUID REFERENCES purchases(server_id),
    batch_number TEXT,
    expiry_date DATE,
    qty_in NUMERIC(18,3) NOT NULL DEFAULT 0,
    qty_remaining NUMERIC(18,3) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS stock_ledger (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    product_id UUID NOT NULL REFERENCES products(server_id),
    source_type TEXT NOT NULL,
    source_id UUID,
    quantity_change NUMERIC(18,3) NOT NULL,
    unit_cost NUMERIC(14,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ledger_entries (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    client_record_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    account_type TEXT NOT NULL,
    direction TEXT NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    linked_item_id UUID,
    tx_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, client_record_id)
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    device_id TEXT NOT NULL,
    client_op_id UUID NOT NULL,
    request_hash TEXT NOT NULL,
    response_code INTEGER,
    response_body JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, device_id, client_op_id)
);

CREATE TABLE IF NOT EXISTS conflict_log (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    table_name TEXT NOT NULL,
    client_record_id UUID,
    device_id TEXT,
    reason TEXT NOT NULL,
    client_payload JSONB,
    server_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_tenant_updated_at ON products(tenant_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_bills_tenant_updated_at ON bills(tenant_id, updated_at);

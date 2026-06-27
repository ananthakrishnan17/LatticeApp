SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS ec_orders (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    ec_customer_id UUID,
    bill_id UUID REFERENCES bills(server_id),
    order_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    shipping_address JSONB NOT NULL DEFAULT '{}',
    billing_address JSONB NOT NULL DEFAULT '{}',
    subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
    discount NUMERIC(14,2) NOT NULL DEFAULT 0,
    coupon_discount NUMERIC(14,2) NOT NULL DEFAULT 0,
    shipping_charge NUMERIC(14,2) NOT NULL DEFAULT 0,
    gst_total NUMERIC(14,2) NOT NULL DEFAULT 0,
    payment_mode TEXT NOT NULL DEFAULT 'razorpay',
    confirmed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_orders_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_orders_number_tenant UNIQUE(tenant_id, order_number),
    CONSTRAINT fk_ec_orders_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_orders_customer_tenant') THEN
        ALTER TABLE ec_orders ADD CONSTRAINT fk_ec_orders_customer_tenant
            FOREIGN KEY (ec_customer_id, tenant_id) REFERENCES ec_customers(server_id, tenant_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ec_order_items (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    order_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    product_name TEXT NOT NULL,
    variant_label TEXT,
    qty INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(14,2) NOT NULL,
    gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    gst_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_order_items_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_order_items_order_tenant
        FOREIGN KEY (order_id, tenant_id)
        REFERENCES ec_orders(server_id, tenant_id),
    CONSTRAINT fk_ec_order_items_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_payments (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    order_id UUID NOT NULL,
    gateway TEXT NOT NULL DEFAULT 'razorpay',
    gateway_order_id TEXT,
    gateway_payment_id TEXT,
    gateway_signature TEXT,
    amount NUMERIC(14,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'initiated',
    raw_response JSONB DEFAULT '{}',
    refund_amount NUMERIC(14,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_payments_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_payments_order_tenant
        FOREIGN KEY (order_id, tenant_id)
        REFERENCES ec_orders(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_shipments (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    order_id UUID NOT NULL,
    courier_name TEXT,
    tracking_number TEXT,
    tracking_url TEXT,
    estimated_delivery DATE,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_shipments_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_shipments_order_tenant
        FOREIGN KEY (order_id, tenant_id)
        REFERENCES ec_orders(server_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_ec_orders_storefront ON ec_orders(storefront_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_orders_customer ON ec_orders(ec_customer_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_orders_number ON ec_orders(order_number);

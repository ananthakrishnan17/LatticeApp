SET search_path TO app_core, public;

-- Low-stock threshold on product listings
ALTER TABLE ec_product_listings
    ADD COLUMN IF NOT EXISTS low_stock_threshold INTEGER NOT NULL DEFAULT 5;

-- Enhanced coupon rules: first-order-only, per-customer usage cap, category restrictions
ALTER TABLE ec_coupons
    ADD COLUMN IF NOT EXISTS first_order_only BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS per_customer_limit INTEGER,
    ADD COLUMN IF NOT EXISTS applicable_categories UUID[] DEFAULT '{}';

-- Customer referral codes
ALTER TABLE ec_customers
    ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS referred_by_code TEXT;

-- Loyalty point ledger
CREATE TABLE IF NOT EXISTS ec_loyalty_transactions (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    ec_customer_id UUID NOT NULL,
    order_id UUID,
    points INTEGER NOT NULL,
    type TEXT NOT NULL DEFAULT 'earn',
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_loyalty_tx_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_loyalty_tx_customer_tenant
        FOREIGN KEY (ec_customer_id, tenant_id)
        REFERENCES ec_customers(server_id, tenant_id)
);

-- Product Q&A
CREATE TABLE IF NOT EXISTS ec_product_qa (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    ec_customer_id UUID,
    question TEXT NOT NULL,
    answer TEXT,
    answered_at TIMESTAMPTZ,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_product_qa_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_product_qa_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_product_qa_customer_tenant') THEN
        ALTER TABLE ec_product_qa ADD CONSTRAINT fk_ec_product_qa_customer_tenant
            FOREIGN KEY (ec_customer_id, tenant_id) REFERENCES ec_customers(server_id, tenant_id);
    END IF;
END $$;

-- Storefront analytics events (view, cart_add, checkout_start, purchase)
CREATE TABLE IF NOT EXISTS ec_storefront_events (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    ec_customer_id UUID,
    session_token TEXT,
    event_type TEXT NOT NULL,
    listing_id UUID,
    order_id UUID,
    meta JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_storefront_events_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_storefront_events_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

-- Back-in-stock alert subscriptions
CREATE TABLE IF NOT EXISTS ec_stock_alerts (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    ec_customer_id UUID,
    email TEXT NOT NULL,
    notified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_stock_alerts_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_stock_alerts_listing_email UNIQUE(listing_id, email),
    CONSTRAINT fk_ec_stock_alerts_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_ec_loyalty_tx_customer ON ec_loyalty_transactions(ec_customer_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_product_qa_listing ON ec_product_qa(listing_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_storefront_events_type ON ec_storefront_events(storefront_id, event_type, created_at);
CREATE INDEX IF NOT EXISTS idx_ec_stock_alerts_listing ON ec_stock_alerts(listing_id, tenant_id);

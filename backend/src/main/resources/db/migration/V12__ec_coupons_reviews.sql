SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS ec_coupons (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    code TEXT NOT NULL,
    discount_type TEXT NOT NULL DEFAULT 'percentage',
    discount_value NUMERIC(14,2) NOT NULL,
    min_order_amount NUMERIC(14,2) DEFAULT 0,
    max_discount_cap NUMERIC(14,2),
    usage_limit INTEGER,
    usage_count INTEGER NOT NULL DEFAULT 0,
    applicable_products UUID[] DEFAULT '{}',
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_coupons_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_coupons_code_storefront UNIQUE(storefront_id, code),
    CONSTRAINT fk_ec_coupons_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_coupon_usages (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    coupon_id UUID NOT NULL,
    order_id UUID NOT NULL,
    ec_customer_id UUID,
    discount_applied NUMERIC(14,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_coupon_usages_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_coupon_usages_coupon_tenant
        FOREIGN KEY (coupon_id, tenant_id)
        REFERENCES ec_coupons(server_id, tenant_id),
    CONSTRAINT fk_ec_coupon_usages_order_tenant
        FOREIGN KEY (order_id, tenant_id)
        REFERENCES ec_orders(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_coupon_usages_customer_tenant') THEN
        ALTER TABLE ec_coupon_usages ADD CONSTRAINT fk_ec_coupon_usages_customer_tenant
            FOREIGN KEY (ec_customer_id, tenant_id) REFERENCES ec_customers(server_id, tenant_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ec_reviews (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    ec_customer_id UUID NOT NULL,
    order_id UUID NOT NULL,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title TEXT,
    body TEXT,
    is_verified_purchase BOOLEAN NOT NULL DEFAULT TRUE,
    status TEXT NOT NULL DEFAULT 'pending',
    helpful_votes INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_reviews_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_reviews_listing_customer_order UNIQUE(listing_id, ec_customer_id, order_id),
    CONSTRAINT fk_ec_reviews_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id),
    CONSTRAINT fk_ec_reviews_customer_tenant
        FOREIGN KEY (ec_customer_id, tenant_id)
        REFERENCES ec_customers(server_id, tenant_id),
    CONSTRAINT fk_ec_reviews_order_tenant
        FOREIGN KEY (order_id, tenant_id)
        REFERENCES ec_orders(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_serviceable_pincodes (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    pincode TEXT NOT NULL,
    extra_shipping_charge NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_serviceable_pincodes_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_serviceable_pincodes_storefront_pincode UNIQUE(storefront_id, pincode),
    CONSTRAINT fk_ec_serviceable_pincodes_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

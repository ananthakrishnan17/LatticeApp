SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS ec_customers (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    customer_id UUID REFERENCES customers(server_id),
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    email_verify_token TEXT,
    reset_password_token TEXT,
    reset_password_sent_at TIMESTAMPTZ,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    loyalty_points INTEGER NOT NULL DEFAULT 0,
    default_address_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_customers_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_customers_email_storefront UNIQUE(storefront_id, email),
    CONSTRAINT fk_ec_customers_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_addresses (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    ec_customer_id UUID NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pincode TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'India',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    label TEXT DEFAULT 'home',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_addresses_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_addresses_customer_tenant
        FOREIGN KEY (ec_customer_id, tenant_id)
        REFERENCES ec_customers(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_customers_default_address') THEN
        ALTER TABLE ec_customers ADD CONSTRAINT fk_ec_customers_default_address
            FOREIGN KEY (default_address_id, tenant_id) REFERENCES ec_addresses(server_id, tenant_id) DEFERRABLE INITIALLY DEFERRED;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ec_carts (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    ec_customer_id UUID,
    session_token TEXT NOT NULL UNIQUE,
    coupon_id UUID,
    coupon_code TEXT,
    coupon_discount NUMERIC(14,2) NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '30 days',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_carts_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_carts_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_carts_customer_tenant') THEN
        ALTER TABLE ec_carts ADD CONSTRAINT fk_ec_carts_customer_tenant
            FOREIGN KEY (ec_customer_id, tenant_id) REFERENCES ec_customers(server_id, tenant_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ec_cart_items (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    cart_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    variant_id UUID,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(14,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_cart_items_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_cart_items_cart_tenant
        FOREIGN KEY (cart_id, tenant_id)
        REFERENCES ec_carts(server_id, tenant_id),
    CONSTRAINT fk_ec_cart_items_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_cart_items_variant_tenant') THEN
        ALTER TABLE ec_cart_items ADD CONSTRAINT fk_ec_cart_items_variant_tenant
            FOREIGN KEY (variant_id, tenant_id) REFERENCES ec_product_variants(server_id, tenant_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ec_wishlists (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    ec_customer_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_wishlists_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_wishlists_customer_listing UNIQUE(ec_customer_id, listing_id),
    CONSTRAINT fk_ec_wishlists_customer_tenant
        FOREIGN KEY (ec_customer_id, tenant_id)
        REFERENCES ec_customers(server_id, tenant_id),
    CONSTRAINT fk_ec_wishlists_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_ec_carts_session_token ON ec_carts(session_token);
CREATE INDEX IF NOT EXISTS idx_ec_carts_customer ON ec_carts(ec_customer_id, tenant_id);

SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS ec_storefronts (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id),
    slug TEXT NOT NULL UNIQUE,
    custom_domain TEXT,
    store_name TEXT NOT NULL,
    theme_config JSONB DEFAULT '{}',
    logo TEXT,
    meta JSONB DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_storefronts_server_tenant UNIQUE(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_product_listings (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    product_id UUID NOT NULL REFERENCES products(server_id),
    ec_selling_price NUMERIC(14,2) NOT NULL,
    ec_compare_price NUMERIC(14,2),
    seo_slug TEXT NOT NULL UNIQUE,
    tags TEXT[] DEFAULT '{}',
    visibility TEXT NOT NULL DEFAULT 'public',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_product_listings_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_product_listings_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_product_images (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_product_images_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_product_images_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_product_variants (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    variant_label TEXT NOT NULL,
    sku TEXT,
    ec_price NUMERIC(14,2) NOT NULL,
    stock_override NUMERIC(18,3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_product_variants_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_product_variants_listing_tenant
        FOREIGN KEY (listing_id, tenant_id)
        REFERENCES ec_product_listings(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_banners (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    position TEXT NOT NULL DEFAULT 'hero',
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    cta_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_banners_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_banners_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_ec_product_listings_storefront ON ec_product_listings(storefront_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_product_listings_seo_slug ON ec_product_listings(seo_slug);

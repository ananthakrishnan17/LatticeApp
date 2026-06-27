SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS ec_notifications (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    ec_customer_id UUID NOT NULL,
    channel TEXT NOT NULL DEFAULT 'email',
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    reference_id UUID,
    payload JSONB DEFAULT '{}',
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_notifications_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_notifications_customer_tenant
        FOREIGN KEY (ec_customer_id, tenant_id)
        REFERENCES ec_customers(server_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS ec_abandoned_carts (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    cart_id UUID NOT NULL,
    ec_customer_id UUID,
    email TEXT,
    reminder_1_sent_at TIMESTAMPTZ,
    reminder_2_sent_at TIMESTAMPTZ,
    recovered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_abandoned_carts_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_abandoned_carts_cart_tenant
        FOREIGN KEY (cart_id, tenant_id)
        REFERENCES ec_carts(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_abandoned_carts_customer_tenant') THEN
        ALTER TABLE ec_abandoned_carts ADD CONSTRAINT fk_ec_abandoned_carts_customer_tenant
            FOREIGN KEY (ec_customer_id, tenant_id) REFERENCES ec_customers(server_id, tenant_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ec_page_slugs (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    slug TEXT NOT NULL,
    page_type TEXT NOT NULL DEFAULT 'product',
    target_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_page_slugs_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT uq_ec_page_slugs_storefront_slug UNIQUE(storefront_id, slug),
    CONSTRAINT fk_ec_page_slugs_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_ec_notifications_customer ON ec_notifications(ec_customer_id, status);
CREATE INDEX IF NOT EXISTS idx_ec_page_slugs_storefront ON ec_page_slugs(storefront_id, slug);

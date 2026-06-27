SET search_path TO app_core, public;

-- Campaign banners
CREATE TABLE IF NOT EXISTS ec_campaigns (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID NOT NULL,
    name TEXT NOT NULL,
    banner TEXT NOT NULL,
    starts_at DATE NOT NULL,
    ends_at DATE NOT NULL,
    impressions BIGINT NOT NULL DEFAULT 0,
    clicks BIGINT NOT NULL DEFAULT 0,
    orders_count BIGINT NOT NULL DEFAULT 0,
    revenue NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_campaigns_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_campaigns_storefront_tenant
        FOREIGN KEY (storefront_id, tenant_id)
        REFERENCES ec_storefronts(server_id, tenant_id)
);

-- Support tickets (customer-submitted)
CREATE TABLE IF NOT EXISTS ec_support_tickets (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    storefront_id UUID,
    ec_customer_id UUID,
    subject TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    admin_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_support_tickets_server_tenant UNIQUE(server_id, tenant_id)
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ec_support_tickets_customer_tenant') THEN
        ALTER TABLE ec_support_tickets ADD CONSTRAINT fk_ec_support_tickets_customer_tenant
            FOREIGN KEY (ec_customer_id, tenant_id) REFERENCES ec_customers(server_id, tenant_id);
    END IF;
END $$;

-- Per-customer notification channel preferences
CREATE TABLE IF NOT EXISTS ec_notification_preferences (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    ec_customer_id UUID NOT NULL,
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    whatsapp_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    order_updates BOOLEAN NOT NULL DEFAULT TRUE,
    price_drop_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    stock_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ec_notification_prefs_customer UNIQUE(ec_customer_id, tenant_id),
    CONSTRAINT uq_ec_notification_prefs_server_tenant UNIQUE(server_id, tenant_id),
    CONSTRAINT fk_ec_notification_prefs_customer_tenant
        FOREIGN KEY (ec_customer_id, tenant_id)
        REFERENCES ec_customers(server_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_ec_campaigns_storefront ON ec_campaigns(storefront_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_support_tickets_customer ON ec_support_tickets(ec_customer_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_support_tickets_status ON ec_support_tickets(tenant_id, status);

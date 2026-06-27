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

INSERT INTO tenant_licenses(
    tenant_id,
    license_key,
    is_active,
    activated_at,
    expires_at
)
SELECT
    t.server_id,
    CONCAT('AUTO-LICENSE-', REPLACE(t.server_id::text, '-', '')),
    TRUE,
    now(),
    now() + interval '365 days'
FROM tenants t
LEFT JOIN tenant_licenses l ON l.tenant_id = t.server_id
WHERE l.tenant_id IS NULL;

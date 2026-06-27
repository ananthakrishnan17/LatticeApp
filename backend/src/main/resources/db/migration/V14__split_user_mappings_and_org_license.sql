SET search_path TO app_core, public;

CREATE TABLE IF NOT EXISTS user_organization_mappings (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(server_id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(server_id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, user_id, organization_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_org_primary
    ON user_organization_mappings(tenant_id, user_id)
    WHERE is_primary = true;

CREATE TABLE IF NOT EXISTS user_branch_mappings (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(server_id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(server_id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, user_id, branch_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_branch_primary
    ON user_branch_mappings(tenant_id, user_id)
    WHERE is_primary = true;

CREATE TABLE IF NOT EXISTS user_scope_role_mappings (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(server_id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(server_id),
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, user_id, role_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_scope_role_primary
    ON user_scope_role_mappings(tenant_id, user_id)
    WHERE is_primary = true;

CREATE TABLE IF NOT EXISTS organization_license_mappings (
    server_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(server_id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(server_id) ON DELETE CASCADE,
    tenant_license_id UUID NOT NULL REFERENCES tenant_licenses(server_id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, organization_id, tenant_license_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_org_license_active
    ON organization_license_mappings(tenant_id, organization_id)
    WHERE is_active = true;

INSERT INTO user_organization_mappings(tenant_id, user_id, organization_id, is_primary, is_active, created_at, updated_at)
SELECT
    m.tenant_id,
    m.user_id,
    m.organization_id,
    bool_or(m.is_primary) AS is_primary,
    bool_or(m.is_active) AS is_active,
    min(m.created_at) AS created_at,
    max(m.updated_at) AS updated_at
FROM user_role_mappings m
GROUP BY m.tenant_id, m.user_id, m.organization_id
ON CONFLICT (tenant_id, user_id, organization_id)
DO UPDATE SET
    is_primary = excluded.is_primary,
    is_active = excluded.is_active,
    updated_at = now();

INSERT INTO user_branch_mappings(tenant_id, user_id, branch_id, is_primary, is_active, created_at, updated_at)
SELECT
    m.tenant_id,
    m.user_id,
    m.branch_id,
    bool_or(m.is_primary) AS is_primary,
    bool_or(m.is_active) AS is_active,
    min(m.created_at) AS created_at,
    max(m.updated_at) AS updated_at
FROM user_role_mappings m
GROUP BY m.tenant_id, m.user_id, m.branch_id
ON CONFLICT (tenant_id, user_id, branch_id)
DO UPDATE SET
    is_primary = excluded.is_primary,
    is_active = excluded.is_active,
    updated_at = now();

INSERT INTO user_scope_role_mappings(tenant_id, user_id, role_id, is_primary, is_active, created_at, updated_at)
SELECT
    m.tenant_id,
    m.user_id,
    m.role_id,
    bool_or(m.is_primary) AS is_primary,
    bool_or(m.is_active) AS is_active,
    min(m.created_at) AS created_at,
    max(m.updated_at) AS updated_at
FROM user_role_mappings m
GROUP BY m.tenant_id, m.user_id, m.role_id
ON CONFLICT (tenant_id, user_id, role_id)
DO UPDATE SET
    is_primary = excluded.is_primary,
    is_active = excluded.is_active,
    updated_at = now();

INSERT INTO organization_license_mappings(tenant_id, organization_id, tenant_license_id, is_active, created_at, updated_at)
SELECT
    o.tenant_id,
    o.server_id,
    l.server_id,
    COALESCE(l.is_active, FALSE),
    now(),
    now()
FROM organizations o
JOIN tenant_licenses l ON l.tenant_id = o.tenant_id
WHERE NOT EXISTS (
    SELECT 1
    FROM organization_license_mappings olm
    WHERE olm.tenant_id = o.tenant_id
      AND olm.organization_id = o.server_id
);

ALTER TABLE users
    DROP COLUMN IF EXISTS role,
    DROP COLUMN IF EXISTS pin_hash,
    DROP COLUMN IF EXISTS can_bill,
    DROP COLUMN IF EXISTS can_view_reports,
    DROP COLUMN IF EXISTS can_manage_products,
    DROP COLUMN IF EXISTS can_manage_masters,
    DROP COLUMN IF EXISTS can_view_expenses,
    DROP COLUMN IF EXISTS can_manage_purchase,
    DROP COLUMN IF EXISTS can_view_dashboard;

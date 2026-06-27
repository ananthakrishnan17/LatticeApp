SET search_path TO app_core, public;

-- ─────────────────────────────────────────────
-- Seed: Company / Main Branch / Owner / Anand
-- ─────────────────────────────────────────────

-- 1. Tenant (top-level account)
INSERT INTO tenants(server_id, tenant_code, name)
VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'company',
    'Company'
)
ON CONFLICT (tenant_code) DO NOTHING;

-- 2. License for the tenant (required for login)
INSERT INTO tenant_licenses(
    tenant_id,
    license_key,
    is_active,
    activated_at,
    expires_at
)
SELECT
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'LICENSE-COMPANY-ANAND',
    TRUE,
    now(),
    now() + interval '3650 days'
WHERE NOT EXISTS (
    SELECT 1 FROM tenant_licenses
    WHERE tenant_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

-- 3. Organization (the company)
-- Use dynamic SQL so we can supply the `code` column when the table has it (some
-- deployments have `code TEXT NOT NULL` from an earlier schema version).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'organizations'
          AND column_name  = 'code'
    ) THEN
        EXECUTE $dyn$
            INSERT INTO organizations(server_id, tenant_id, code, name, is_default)
            VALUES (
                'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
                'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                'company',
                'Company',
                TRUE
            )
            ON CONFLICT (server_id) DO NOTHING
        $dyn$;
    ELSE
        INSERT INTO organizations(server_id, tenant_id, name, is_default)
        VALUES (
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'Company',
            TRUE
        )
        ON CONFLICT (server_id) DO NOTHING;
    END IF;
END $$;

-- 4. Main Branch
-- Same defensive pattern for branches in case it also has a `code` column.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'branches'
          AND column_name  = 'code'
    ) THEN
        EXECUTE $dyn$
            INSERT INTO branches(server_id, tenant_id, organization_id, code, name, is_default)
            VALUES (
                'cccccccc-cccc-cccc-cccc-cccccccccccc',
                'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
                'main-branch',
                'Main Branch',
                TRUE
            )
            ON CONFLICT (server_id) DO NOTHING
        $dyn$;
    ELSE
        INSERT INTO branches(server_id, tenant_id, organization_id, name, is_default)
        VALUES (
            'cccccccc-cccc-cccc-cccc-cccccccccccc',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            'Main Branch',
            TRUE
        )
        ON CONFLICT (server_id) DO NOTHING;
    END IF;
END $$;

-- 5. User: Anand  (password: 1234)
INSERT INTO users(server_id, tenant_id, username, password_hash, is_active)
VALUES (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Anand',
    '$2b$10$sO2MqcCngEYlqX0GnX9VYu3It0JF4hNSfesnIM4tXw.Oq8paDGVi.',
    TRUE
)
ON CONFLICT (tenant_id, username) DO NOTHING;

-- 6. Owner role mapping (user_role_mappings)
INSERT INTO user_role_mappings(
    tenant_id, user_id, organization_id, branch_id, role_id, is_primary, is_active
)
SELECT
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    r.server_id,
    TRUE,
    TRUE
FROM roles r
WHERE r.role_code = 'owner'
ON CONFLICT (tenant_id, user_id, organization_id, branch_id, role_id) DO NOTHING;

-- 7. user_organization_mappings
INSERT INTO user_organization_mappings(tenant_id, user_id, organization_id, is_primary, is_active)
VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    TRUE,
    TRUE
)
ON CONFLICT (tenant_id, user_id, organization_id) DO NOTHING;

-- 8. user_branch_mappings
INSERT INTO user_branch_mappings(tenant_id, user_id, branch_id, is_primary, is_active)
VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    TRUE,
    TRUE
)
ON CONFLICT (tenant_id, user_id, branch_id) DO NOTHING;

-- 9. user_scope_role_mappings
INSERT INTO user_scope_role_mappings(tenant_id, user_id, role_id, is_primary, is_active)
SELECT
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    r.server_id,
    TRUE,
    TRUE
FROM roles r
WHERE r.role_code = 'owner'
ON CONFLICT (tenant_id, user_id, role_id) DO NOTHING;

-- 10. organization_license_mappings
INSERT INTO organization_license_mappings(tenant_id, organization_id, tenant_license_id, is_active)
SELECT
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    l.server_id,
    TRUE
FROM tenant_licenses l
WHERE l.tenant_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
ON CONFLICT (tenant_id, organization_id, tenant_license_id) DO NOTHING;

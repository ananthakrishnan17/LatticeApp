SET search_path TO app_core, public;

-- 1. Tenants (Top-level accounts for each customer)
INSERT INTO tenants(server_id, tenant_code, name) VALUES 
('c1111111-1111-1111-1111-111111111111', 'karur', 'karur super market'),
('c2222222-2222-2222-2222-222222222222', 'suntar', 'suntar shop'),
('c3333333-3333-3333-3333-333333333333', 'amar', 'amar shop'),
('c4444444-4444-4444-4444-444444444444', 'nammananban', 'nammananban')
ON CONFLICT (tenant_code) DO NOTHING;

-- 2. Tenant Licenses (1 year validity, 10 users max)
INSERT INTO tenant_licenses(tenant_id, license_key, license_type, max_users, is_active, activated_at, expires_at)
SELECT tenant_id, license_key, license_type, max_users, is_active, activated_at, expires_at
FROM (
  VALUES 
    ('c1111111-1111-1111-1111-111111111111'::uuid, 'LICENSE-KARUR', 'online', 10, true, now(), now() + interval '1 year'),
    ('c2222222-2222-2222-2222-222222222222'::uuid, 'LICENSE-SUNTAR', 'online', 10, true, now(), now() + interval '1 year'),
    ('c3333333-3333-3333-3333-333333333333'::uuid, 'LICENSE-AMAR', 'online', 10, true, now(), now() + interval '1 year'),
    ('c4444444-4444-4444-4444-444444444444'::uuid, 'LICENSE-NAMMA', 'online', 10, true, now(), now() + interval '1 year')
) AS v(tenant_id, license_key, license_type, max_users, is_active, activated_at, expires_at)
WHERE NOT EXISTS (
    SELECT 1 FROM tenant_licenses tl WHERE tl.tenant_id = v.tenant_id
);

-- 3. Organizations (Companies)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core' AND table_name = 'organizations' AND column_name = 'code'
    ) THEN
        EXECUTE $dyn$
            INSERT INTO organizations(server_id, tenant_id, code, name, is_default) VALUES 
            ('c1111111-1111-1111-1111-111111111112', 'c1111111-1111-1111-1111-111111111111', 'karur', 'karur super market', TRUE),
            ('c2222222-2222-2222-2222-222222222223', 'c2222222-2222-2222-2222-222222222222', 'suntar', 'suntar shop', TRUE),
            ('c3333333-3333-3333-3333-333333333334', 'c3333333-3333-3333-3333-333333333333', 'amar', 'amar shop', TRUE),
            ('c4444444-4444-4444-4444-444444444445', 'c4444444-4444-4444-4444-444444444444', 'nammananban', 'nammananban', TRUE)
            ON CONFLICT (server_id) DO NOTHING
        $dyn$;
    ELSE
        INSERT INTO organizations(server_id, tenant_id, name, is_default) VALUES 
        ('c1111111-1111-1111-1111-111111111112', 'c1111111-1111-1111-1111-111111111111', 'karur super market', TRUE),
        ('c2222222-2222-2222-2222-222222222223', 'c2222222-2222-2222-2222-222222222222', 'suntar shop', TRUE),
        ('c3333333-3333-3333-3333-333333333334', 'c3333333-3333-3333-3333-333333333333', 'amar shop', TRUE),
        ('c4444444-4444-4444-4444-444444444445', 'c4444444-4444-4444-4444-444444444444', 'nammananban', TRUE)
        ON CONFLICT (server_id) DO NOTHING;
    END IF;
END $$;

-- 4. Main Branches
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core' AND table_name = 'branches' AND column_name = 'code'
    ) THEN
        EXECUTE $dyn$
            INSERT INTO branches(server_id, tenant_id, organization_id, code, name, is_default) VALUES 
            ('c1111111-1111-1111-1111-111111111113', 'c1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111112', 'main-karur', 'Main Branch', TRUE),
            ('c2222222-2222-2222-2222-222222222224', 'c2222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222223', 'main-suntar', 'Main Branch', TRUE),
            ('c3333333-3333-3333-3333-333333333335', 'c3333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333334', 'main-amar', 'Main Branch', TRUE),
            ('c4444444-4444-4444-4444-444444444446', 'c4444444-4444-4444-4444-444444444444', 'c4444444-4444-4444-4444-444444444445', 'main-namma', 'Main Branch', TRUE)
            ON CONFLICT (server_id) DO NOTHING
        $dyn$;
    ELSE
        INSERT INTO branches(server_id, tenant_id, organization_id, name, is_default) VALUES 
        ('c1111111-1111-1111-1111-111111111113', 'c1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111112', 'Main Branch', TRUE),
        ('c2222222-2222-2222-2222-222222222224', 'c2222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222223', 'Main Branch', TRUE),
        ('c3333333-3333-3333-3333-333333333335', 'c3333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333334', 'Main Branch', TRUE),
        ('c4444444-4444-4444-4444-444444444446', 'c4444444-4444-4444-4444-444444444444', 'c4444444-4444-4444-4444-444444444445', 'Main Branch', TRUE)
        ON CONFLICT (server_id) DO NOTHING;
    END IF;
END $$;

-- 5. Users (all using '1234' as password)
INSERT INTO users(server_id, tenant_id, username, password_hash, is_active) VALUES 
('c1111111-1111-1111-1111-111111111114', 'c1111111-1111-1111-1111-111111111111', 'karur', '$2b$10$sO2MqcCngEYlqX0GnX9VYu3It0JF4hNSfesnIM4tXw.Oq8paDGVi.', TRUE),
('c2222222-2222-2222-2222-222222222225', 'c2222222-2222-2222-2222-222222222222', 'suntar', '$2b$10$sO2MqcCngEYlqX0GnX9VYu3It0JF4hNSfesnIM4tXw.Oq8paDGVi.', TRUE),
('c3333333-3333-3333-3333-333333333336', 'c3333333-3333-3333-3333-333333333333', 'amar', '$2b$10$sO2MqcCngEYlqX0GnX9VYu3It0JF4hNSfesnIM4tXw.Oq8paDGVi.', TRUE),
('c4444444-4444-4444-4444-444444444447', 'c4444444-4444-4444-4444-444444444444', 'bala', '$2b$10$sO2MqcCngEYlqX0GnX9VYu3It0JF4hNSfesnIM4tXw.Oq8paDGVi.', TRUE)
ON CONFLICT (tenant_id, username) DO NOTHING;

-- 6. Owner role mapping (user_role_mappings)
INSERT INTO user_role_mappings(tenant_id, user_id, organization_id, branch_id, role_id, is_primary, is_active)
SELECT t.tenant_id, t.user_id, t.org_id, t.branch_id, r.server_id, TRUE, TRUE
FROM (
  VALUES 
    ('c1111111-1111-1111-1111-111111111111'::uuid, 'c1111111-1111-1111-1111-111111111114'::uuid, 'c1111111-1111-1111-1111-111111111112'::uuid, 'c1111111-1111-1111-1111-111111111113'::uuid),
    ('c2222222-2222-2222-2222-222222222222'::uuid, 'c2222222-2222-2222-2222-222222222225'::uuid, 'c2222222-2222-2222-2222-222222222223'::uuid, 'c2222222-2222-2222-2222-222222222224'::uuid),
    ('c3333333-3333-3333-3333-333333333333'::uuid, 'c3333333-3333-3333-3333-333333333336'::uuid, 'c3333333-3333-3333-3333-333333333334'::uuid, 'c3333333-3333-3333-3333-333333333335'::uuid),
    ('c4444444-4444-4444-4444-444444444444'::uuid, 'c4444444-4444-4444-4444-444444444447'::uuid, 'c4444444-4444-4444-4444-444444444445'::uuid, 'c4444444-4444-4444-4444-444444444446'::uuid)
) AS t(tenant_id, user_id, org_id, branch_id)
CROSS JOIN roles r
WHERE r.role_code = 'owner'
ON CONFLICT (tenant_id, user_id, organization_id, branch_id, role_id) DO NOTHING;

-- 7. user_organization_mappings
INSERT INTO user_organization_mappings(tenant_id, user_id, organization_id, is_primary, is_active) VALUES 
('c1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111114', 'c1111111-1111-1111-1111-111111111112', TRUE, TRUE),
('c2222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222225', 'c2222222-2222-2222-2222-222222222223', TRUE, TRUE),
('c3333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333336', 'c3333333-3333-3333-3333-333333333334', TRUE, TRUE),
('c4444444-4444-4444-4444-444444444444', 'c4444444-4444-4444-4444-444444444447', 'c4444444-4444-4444-4444-444444444445', TRUE, TRUE)
ON CONFLICT (tenant_id, user_id, organization_id) DO NOTHING;

-- 8. user_branch_mappings
INSERT INTO user_branch_mappings(tenant_id, user_id, branch_id, is_primary, is_active) VALUES 
('c1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111114', 'c1111111-1111-1111-1111-111111111113', TRUE, TRUE),
('c2222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222225', 'c2222222-2222-2222-2222-222222222224', TRUE, TRUE),
('c3333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333336', 'c3333333-3333-3333-3333-333333333335', TRUE, TRUE),
('c4444444-4444-4444-4444-444444444444', 'c4444444-4444-4444-4444-444444444447', 'c4444444-4444-4444-4444-444444444446', TRUE, TRUE)
ON CONFLICT (tenant_id, user_id, branch_id) DO NOTHING;

-- 9. user_scope_role_mappings
INSERT INTO user_scope_role_mappings(tenant_id, user_id, role_id, is_primary, is_active)
SELECT t.tenant_id, t.user_id, r.server_id, TRUE, TRUE
FROM (
  VALUES 
    ('c1111111-1111-1111-1111-111111111111'::uuid, 'c1111111-1111-1111-1111-111111111114'::uuid),
    ('c2222222-2222-2222-2222-222222222222'::uuid, 'c2222222-2222-2222-2222-222222222225'::uuid),
    ('c3333333-3333-3333-3333-333333333333'::uuid, 'c3333333-3333-3333-3333-333333333336'::uuid),
    ('c4444444-4444-4444-4444-444444444444'::uuid, 'c4444444-4444-4444-4444-444444444447'::uuid)
) AS t(tenant_id, user_id)
CROSS JOIN roles r
WHERE r.role_code = 'owner'
ON CONFLICT (tenant_id, user_id, role_id) DO NOTHING;

-- 10. organization_license_mappings
INSERT INTO organization_license_mappings(tenant_id, organization_id, tenant_license_id, is_active)
SELECT t.tenant_id, t.org_id, l.server_id, TRUE
FROM (
  VALUES 
    ('c1111111-1111-1111-1111-111111111111'::uuid, 'c1111111-1111-1111-1111-111111111112'::uuid),
    ('c2222222-2222-2222-2222-222222222222'::uuid, 'c2222222-2222-2222-2222-222222222223'::uuid),
    ('c3333333-3333-3333-3333-333333333333'::uuid, 'c3333333-3333-3333-3333-333333333334'::uuid),
    ('c4444444-4444-4444-4444-444444444444'::uuid, 'c4444444-4444-4444-4444-444444444445'::uuid)
) AS t(tenant_id, org_id)
JOIN tenant_licenses l ON l.tenant_id = t.tenant_id
ON CONFLICT (tenant_id, organization_id, tenant_license_id) DO NOTHING;

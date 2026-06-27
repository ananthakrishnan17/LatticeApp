SET search_path TO app_core, public;

-- Add tenant_id to branches if it was created before V7 introduced it
-- (CREATE TABLE IF NOT EXISTS in V7 silently skips creation when branches already exists,
--  leaving the table without the tenant_id column and causing subsequent INSERTs to fail)

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'branches'
          AND column_name  = 'tenant_id'
    ) THEN
        ALTER TABLE branches
            ADD COLUMN tenant_id UUID REFERENCES tenants(server_id) ON DELETE CASCADE;

        -- Remove orphaned branches that have no matching organization
        DELETE FROM branches
        WHERE organization_id NOT IN (SELECT server_id FROM organizations);

        -- Populate tenant_id from the parent organization row
        UPDATE branches b
        SET tenant_id = o.tenant_id
        FROM organizations o
        WHERE b.organization_id = o.server_id;

        -- Now enforce NOT NULL (all rows should have a value after the UPDATE above)
        ALTER TABLE branches
            ALTER COLUMN tenant_id SET NOT NULL;
    END IF;
END $$;

-- Ensure the unique constraint required by V8 exists regardless
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_branches_server_tenant') THEN
        ALTER TABLE branches
            ADD CONSTRAINT uq_branches_server_tenant UNIQUE (server_id, tenant_id);
    END IF;
END $$;

-- Seed roles that V7 would have inserted (idempotent)
INSERT INTO roles(role_code, display_name, scope)
VALUES
    ('owner',        'Owner',        'organization'),
    ('branch_admin', 'Branch Admin', 'branch'),
    ('staff',        'Staff',        'branch')
ON CONFLICT (role_code) DO NOTHING;

-- Seed one default organization per tenant that has none (idempotent)
INSERT INTO organizations(tenant_id, name, is_default)
SELECT
    t.server_id,
    COALESCE(NULLIF(trim(t.name), ''), 'Default Organization'),
    true
FROM tenants t
WHERE NOT EXISTS (
    SELECT 1
    FROM organizations o
    WHERE o.tenant_id = t.server_id
);

-- Ensure exactly one default organization per tenant
WITH ranked_orgs AS (
    SELECT
        o.server_id,
        row_number() OVER (PARTITION BY o.tenant_id ORDER BY o.is_default DESC, o.created_at ASC) AS rn
    FROM organizations o
)
UPDATE organizations o
SET is_default = (r.rn = 1),
    updated_at = now()
FROM ranked_orgs r
WHERE o.server_id = r.server_id
  AND o.is_default IS DISTINCT FROM (r.rn = 1);

-- Seed a default branch per organization that has none (idempotent)
INSERT INTO branches(tenant_id, organization_id, name, is_default)
SELECT
    o.tenant_id,
    o.server_id,
    'Main Branch',
    true
FROM organizations o
WHERE NOT EXISTS (
    SELECT 1
    FROM branches b
    WHERE b.organization_id = o.server_id
);

-- Ensure exactly one default branch per organization
WITH ranked_branches AS (
    SELECT
        b.server_id,
        row_number() OVER (PARTITION BY b.organization_id ORDER BY b.is_default DESC, b.created_at ASC) AS rn
    FROM branches b
)
UPDATE branches b
SET is_default = (r.rn = 1),
    updated_at = now()
FROM ranked_branches r
WHERE b.server_id = r.server_id
  AND b.is_default IS DISTINCT FROM (r.rn = 1);

-- Seed primary user_role_mappings for any users that have none (idempotent)
-- Wrapped in dynamic SQL so PostgreSQL does not attempt to parse/plan the reference
-- to u.role at statement-preparation time when that column no longer exists.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'users'
          AND column_name  = 'role'
    ) THEN
        EXECUTE $dyn$
            INSERT INTO user_role_mappings(
                tenant_id, user_id, organization_id, branch_id, role_id, is_primary, is_active
            )
            SELECT
                u.tenant_id,
                u.server_id,
                o.server_id,
                b.server_id,
                r.server_id,
                true,
                u.is_active
            FROM users u
            JOIN LATERAL (
                SELECT o1.server_id
                FROM organizations o1
                WHERE o1.tenant_id = u.tenant_id
                ORDER BY o1.is_default DESC, o1.created_at ASC
                LIMIT 1
            ) o ON true
            JOIN LATERAL (
                SELECT b1.server_id
                FROM branches b1
                WHERE b1.organization_id = o.server_id
                ORDER BY b1.is_default DESC, b1.created_at ASC
                LIMIT 1
            ) b ON true
            JOIN roles r ON r.role_code = CASE
                WHEN lower(COALESCE(u.role, '')) IN ('admin', 'owner') THEN 'owner'
                WHEN replace(lower(COALESCE(u.role, '')), '-', '_') IN ('branchadmin', 'branch_admin') THEN 'branch_admin'
                ELSE 'staff'
            END
            WHERE NOT EXISTS (
                SELECT 1
                FROM user_role_mappings m
                WHERE m.tenant_id = u.tenant_id
                  AND m.user_id   = u.server_id
                  AND m.is_primary = true
            )
        $dyn$;
    END IF;
END $$;

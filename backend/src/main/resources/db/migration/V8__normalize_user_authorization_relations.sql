SET search_path TO app_core, public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_users_server_tenant') THEN
        ALTER TABLE users
            ADD CONSTRAINT uq_users_server_tenant UNIQUE (server_id, tenant_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_organizations_server_tenant') THEN
        ALTER TABLE organizations
            ADD CONSTRAINT uq_organizations_server_tenant UNIQUE (server_id, tenant_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_branches_server_tenant') THEN
        ALTER TABLE branches
            ADD CONSTRAINT uq_branches_server_tenant UNIQUE (server_id, tenant_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_branches_server_organization') THEN
        ALTER TABLE branches
            ADD CONSTRAINT uq_branches_server_organization UNIQUE (server_id, organization_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_branches_organization_tenant') THEN
        ALTER TABLE branches
            ADD CONSTRAINT fk_branches_organization_tenant
                FOREIGN KEY (organization_id, tenant_id)
                REFERENCES organizations(server_id, tenant_id)
                ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_role_mappings_user_tenant') THEN
        ALTER TABLE user_role_mappings
            ADD CONSTRAINT fk_user_role_mappings_user_tenant
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES users(server_id, tenant_id)
                ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_role_mappings_org_tenant') THEN
        ALTER TABLE user_role_mappings
            ADD CONSTRAINT fk_user_role_mappings_org_tenant
                FOREIGN KEY (organization_id, tenant_id)
                REFERENCES organizations(server_id, tenant_id)
                ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_role_mappings_branch_tenant') THEN
        ALTER TABLE user_role_mappings
            ADD CONSTRAINT fk_user_role_mappings_branch_tenant
                FOREIGN KEY (branch_id, tenant_id)
                REFERENCES branches(server_id, tenant_id)
                ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_role_mappings_branch_org') THEN
        ALTER TABLE user_role_mappings
            ADD CONSTRAINT fk_user_role_mappings_branch_org
                FOREIGN KEY (branch_id, organization_id)
                REFERENCES branches(server_id, organization_id)
                ON DELETE CASCADE;
    END IF;
END $$;

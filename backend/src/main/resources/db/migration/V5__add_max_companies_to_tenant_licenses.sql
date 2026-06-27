SET search_path TO app_core, public;

ALTER TABLE tenant_licenses
    ADD COLUMN IF NOT EXISTS max_companies INTEGER NOT NULL DEFAULT 1;

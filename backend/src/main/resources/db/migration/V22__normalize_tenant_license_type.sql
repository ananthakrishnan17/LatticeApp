SET search_path TO app_core, public;

ALTER TABLE tenant_licenses
    ADD COLUMN IF NOT EXISTS license_type TEXT;

UPDATE tenant_licenses
SET license_type = 'offline'
WHERE COALESCE(BTRIM(license_type), '') = '';

ALTER TABLE tenant_licenses
    ALTER COLUMN license_type SET DEFAULT 'offline';

ALTER TABLE tenant_licenses
    ALTER COLUMN license_type SET NOT NULL;

ALTER TABLE tenant_licenses
    DROP CONSTRAINT IF EXISTS tenant_licenses_license_type_check;

ALTER TABLE tenant_licenses
    ADD CONSTRAINT tenant_licenses_license_type_check
    CHECK (license_type IN ('offline', 'online'));

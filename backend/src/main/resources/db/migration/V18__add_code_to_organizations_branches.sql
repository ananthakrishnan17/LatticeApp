SET search_path TO app_core, public;

-- Add `code` column to organizations if it does not already exist.
-- Deployments whose schema was created before this column was formalized
-- will have it added here; deployments that already have it are unaffected.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'organizations'
          AND column_name  = 'code'
    ) THEN
        ALTER TABLE organizations ADD COLUMN code TEXT NOT NULL DEFAULT '';
    END IF;
END $$;

-- Backfill the seeded Company organization so it has a meaningful code.
UPDATE organizations
SET    code = 'company'
WHERE  server_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  AND  code = '';

-- Add `code` column to branches if it does not already exist.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'branches'
          AND column_name  = 'code'
    ) THEN
        ALTER TABLE branches ADD COLUMN code TEXT NOT NULL DEFAULT '';
    END IF;
END $$;

-- Backfill the seeded Main Branch so it has a meaningful code.
UPDATE branches
SET    code = 'main-branch'
WHERE  server_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  AND  code = '';

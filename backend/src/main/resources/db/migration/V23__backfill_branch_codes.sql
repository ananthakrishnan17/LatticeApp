SET search_path TO app_core, public;

-- Ensure branches.code exists with a DEFAULT so INSERTs that omit the column
-- never fail with a NOT NULL violation.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app_core'
          AND table_name   = 'branches'
          AND column_name  = 'code'
    ) THEN
        ALTER TABLE branches ADD COLUMN code TEXT NOT NULL DEFAULT '';
    ELSE
        -- Column exists – make sure it has a DEFAULT value set.
        ALTER TABLE branches ALTER COLUMN code SET DEFAULT '';
    END IF;
END $$;

-- Backfill any branches whose code is still empty by deriving a slug from the
-- branch name (lower-case, non-alphanumeric runs replaced with hyphens).
UPDATE branches
SET    code = regexp_replace(
                 regexp_replace(lower(trim(name)), '[^a-z0-9]+', '-', 'g'),
                 '^-|-$', '', 'g')
WHERE  COALESCE(trim(code), '') = '';

SET search_path TO app_core, public;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS mobile_number TEXT;

UPDATE users
SET mobile_number = BTRIM(username)
WHERE (mobile_number IS NULL OR BTRIM(mobile_number) = '')
  AND username ~ '^[0-9]{8,15}$';

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_mobile_number
    ON users (mobile_number)
    WHERE mobile_number IS NOT NULL AND BTRIM(mobile_number) <> '';

SET search_path TO app_core, public;

ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;

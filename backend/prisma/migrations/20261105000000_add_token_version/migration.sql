-- Migration: F-04 JWT Security — Add tokenVersion to users table
-- Purpose: Enables server-side token invalidation on password change, password reset, and logout.
--          The tokenVersion is embedded in every issued JWT and verified on each protected request.
--          Incrementing tokenVersion immediately invalidates all previously issued tokens for the user.
-- Safety:  Non-destructive. Adds a new column with DEFAULT 0, so all existing rows get tokenVersion = 0.
--          Legacy tokens without a tokenVersion claim will be treated as version 0 and remain valid
--          until the user's first password change, reset, or logout after migration.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'tokenVersion'
  ) THEN
    ALTER TABLE "users" ADD COLUMN "tokenVersion" INTEGER NOT NULL DEFAULT 0;
  END IF;
END$$;


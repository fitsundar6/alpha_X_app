-- Migration: Add Persistent Password Reset Codes & Forced Password Change Flag
-- 100% non-destructive: uses IF NOT EXISTS, default values, and preserves all existing data and user records.

-- 1. Add mustChangePassword column to users table if not exists
ALTER TABLE "users" 
  ADD COLUMN IF NOT EXISTS "mustChangePassword" BOOLEAN NOT NULL DEFAULT false;

-- 2. Create password_reset_codes table if not exists
CREATE TABLE IF NOT EXISTS "password_reset_codes" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "adminId" TEXT,
    "adminEmail" TEXT,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_codes_pkey" PRIMARY KEY ("id")
);

-- 3. Add foreign key if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'password_reset_codes_userId_fkey'
  ) THEN
    ALTER TABLE "password_reset_codes" 
      ADD CONSTRAINT "password_reset_codes_userId_fkey" 
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END$$;

-- 4. Create indexes if not exists
CREATE INDEX IF NOT EXISTS "password_reset_codes_userId_idx" ON "password_reset_codes"("userId");
CREATE INDEX IF NOT EXISTS "password_reset_codes_expiresAt_idx" ON "password_reset_codes"("expiresAt");

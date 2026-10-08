-- Migration: Add User Status and Verification Audit Log
-- Safely adds UserStatus enum, updates users table, creates user_verification_logs table,
-- and migrates ALL existing users to APPROVED so existing clients are never disrupted.

-- 1. CreateEnum if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'UserStatus') THEN
    CREATE TYPE "UserStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED');
  END IF;
END$$;

-- 2. AlterTable users
ALTER TABLE "users" 
  ADD COLUMN IF NOT EXISTS "status" "UserStatus" NOT NULL DEFAULT 'PENDING',
  ADD COLUMN IF NOT EXISTS "approvedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "approvedBy" TEXT,
  ADD COLUMN IF NOT EXISTS "rejectedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "rejectedBy" TEXT,
  ADD COLUMN IF NOT EXISTS "rejectionReason" TEXT,
  ADD COLUMN IF NOT EXISTS "suspendedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "suspendedBy" TEXT,
  ADD COLUMN IF NOT EXISTS "lastLoginAt" TIMESTAMP(3);

-- 3. CRITICAL DATA INTEGRITY SAFEGUARD FOR EXISTING USERS:
-- Set all existing users to APPROVED status so existing active clients maintain full access.
UPDATE "users"
SET "status" = 'APPROVED',
    "approvedAt" = COALESCE("approvedAt", NOW()),
    "approvedBy" = COALESCE("approvedBy", 'SYSTEM_MIGRATION')
WHERE "approvedAt" IS NULL AND "status" = 'PENDING';

-- 4. CreateTable user_verification_logs
CREATE TABLE IF NOT EXISTS "user_verification_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "adminId" TEXT,
    "adminEmail" TEXT,
    "previousStatus" "UserStatus" NOT NULL,
    "newStatus" "UserStatus" NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_verification_logs_pkey" PRIMARY KEY ("id")
);

-- 5. AddForeignKey if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_verification_logs_userId_fkey'
  ) THEN
    ALTER TABLE "user_verification_logs" 
      ADD CONSTRAINT "user_verification_logs_userId_fkey" 
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END$$;

-- 6. CreateIndex if not exists
CREATE INDEX IF NOT EXISTS "user_verification_logs_userId_idx" ON "user_verification_logs"("userId");

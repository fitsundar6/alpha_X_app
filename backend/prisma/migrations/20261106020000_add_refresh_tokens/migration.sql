-- Migration: 20261106020000_add_refresh_tokens
-- Sequence: Sequential after 20261106010000_add_workout_persistence_and_idempotency
-- Purpose: Introduces persistent SHA-256 hashed refresh tokens with tokenVersion binding,
--          family-bound active session composite index, and two-phase constraint validation.
-- Safety:  Non-destructive. Adds a new table without altering any existing tables.
-- Notice:  Generated for deployment. DO NOT execute directly without database approval.

CREATE TABLE IF NOT EXISTS "refresh_tokens" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "tokenVersion" INTEGER NOT NULL,
    "userId" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "deviceInfo" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "isRevoked" BOOLEAN NOT NULL DEFAULT false,
    "revokedAt" TIMESTAMP(3),
    "revokedReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- Unique index backing @unique (no redundant tokenHash index)
CREATE UNIQUE INDEX IF NOT EXISTS "refresh_tokens_tokenHash_key" ON "refresh_tokens"("tokenHash");

-- B-Tree Query Indexes
CREATE INDEX IF NOT EXISTS "refresh_tokens_userId_idx" ON "refresh_tokens"("userId");
CREATE INDEX IF NOT EXISTS "refresh_tokens_sessionId_idx" ON "refresh_tokens"("sessionId");
CREATE INDEX IF NOT EXISTS "refresh_tokens_familyId_idx" ON "refresh_tokens"("familyId");
CREATE INDEX IF NOT EXISTS "refresh_tokens_expiresAt_idx" ON "refresh_tokens"("expiresAt");

-- Composite index guaranteeing sub-millisecond requireAuth active session validation
CREATE INDEX IF NOT EXISTS "refresh_tokens_session_validation_idx" 
    ON "refresh_tokens"("userId", "sessionId", "familyId", "isRevoked");

-- Safe two-phase foreign key constraint to eliminate lock contention on 'users'
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'refresh_tokens_userId_fkey'
    ) THEN
        ALTER TABLE "refresh_tokens" 
            ADD CONSTRAINT "refresh_tokens_userId_fkey" 
            FOREIGN KEY ("userId") REFERENCES "users"("id") 
            ON DELETE CASCADE ON UPDATE CASCADE NOT VALID;

        ALTER TABLE "refresh_tokens" 
            VALIDATE CONSTRAINT "refresh_tokens_userId_fkey";
    END IF;
END $$;


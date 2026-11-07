-- Migration: BUG-04 Master Admin JWT Revocation — Add revoked_admin_sessions table
-- Purpose: Enables durable, distributed server-side revocation for Master Admin JWT sessions
--          across Vercel serverless containers, cold starts, and process restarts.
-- Safety:  Non-destructive. Adds a new table without altering any existing tables.
-- Notice:  Generated for deployment. DO NOT execute directly in development without database approval.

CREATE TABLE IF NOT EXISTS "revoked_admin_sessions" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT,
    "tokenHash" TEXT,
    "adminEmail" TEXT NOT NULL,
    "reason" TEXT NOT NULL DEFAULT 'LOGOUT',
    "revokedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "revoked_admin_sessions_pkey" PRIMARY KEY ("id")
);

-- Unique indexes
CREATE UNIQUE INDEX IF NOT EXISTS "revoked_admin_sessions_sessionId_key" ON "revoked_admin_sessions"("sessionId");
CREATE UNIQUE INDEX IF NOT EXISTS "revoked_admin_sessions_tokenHash_key" ON "revoked_admin_sessions"("tokenHash");

-- Query indexes
CREATE INDEX IF NOT EXISTS "revoked_admin_sessions_sessionId_idx" ON "revoked_admin_sessions"("sessionId");
CREATE INDEX IF NOT EXISTS "revoked_admin_sessions_tokenHash_idx" ON "revoked_admin_sessions"("tokenHash");
CREATE INDEX IF NOT EXISTS "revoked_admin_sessions_expiresAt_idx" ON "revoked_admin_sessions"("expiresAt");


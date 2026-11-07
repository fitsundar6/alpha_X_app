-- Migration: BUG-02 Workout Serverless Persistence & Idempotency
-- Purpose:
-- 1. Adds idempotencyKey to workout_records to prevent duplicate concurrent saves in distributed/serverless environments.
-- 2. Adds workout_split_plans table to persist custom multi-day workout split definitions across Vercel instances and restarts.
-- Safety: Non-destructive, additive only. Does not alter or drop any existing tables.
-- Notice: Generated for deployment. DO NOT execute directly in development without database approval.

-- 1. Idempotency key for workout_records
ALTER TABLE "workout_records" ADD COLUMN IF NOT EXISTS "idempotencyKey" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "workout_records_idempotencyKey_key" ON "workout_records"("idempotencyKey");
CREATE INDEX IF NOT EXISTS "workout_records_idempotencyKey_idx" ON "workout_records"("idempotencyKey");

-- 2. Workout split plans table
CREATE TABLE IF NOT EXISTS "workout_split_plans" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "splitType" TEXT NOT NULL DEFAULT 'Custom',
    "description" TEXT,
    "frequencyPerWeek" INTEGER NOT NULL DEFAULT 3,
    "clientId" TEXT,
    "clientIdsJson" TEXT,
    "daysJson" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "workout_split_plans_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "workout_split_plans_clientId_idx" ON "workout_split_plans"("clientId");


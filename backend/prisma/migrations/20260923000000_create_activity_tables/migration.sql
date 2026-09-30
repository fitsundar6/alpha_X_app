-- Alpha X Gym PostgreSQL Migration: Daily Step Tracking & Activity System

-- Create UserRole Enum if not exists
DO $$ BEGIN
    CREATE TYPE "UserRole" AS ENUM ('CLIENT', 'TRAINER', 'ADMIN', 'SUPER_ADMIN');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create Users Table if not exists
CREATE TABLE IF NOT EXISTS "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'CLIENT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "users_email_key" ON "users"("email");

-- Create Client Profiles Table
CREATE TABLE IF NOT EXISTS "client_profiles" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "trainerId" TEXT,
    "dailyStepGoal" INTEGER NOT NULL DEFAULT 6000,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "client_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "client_profiles_userId_key" ON "client_profiles"("userId");

-- Create Activity Records Table with Unique Constraint
CREATE TABLE IF NOT EXISTS "activity_records" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "steps" INTEGER NOT NULL DEFAULT 0,
    "stepGoal" INTEGER NOT NULL DEFAULT 6000,
    "cardioMinutes" INTEGER NOT NULL DEFAULT 0,
    "caloriesBurned" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "distanceMeters" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "isGoalAchieved" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "activity_records_pkey" PRIMARY KEY ("id")
);

-- Unique Constraint: Guarantee no duplicate records for the same client on the same day
CREATE UNIQUE INDEX IF NOT EXISTS "activity_records_clientId_date_key" ON "activity_records"("clientId", "date");

-- Indexes for fast query performance
CREATE INDEX IF NOT EXISTS "activity_records_clientId_idx" ON "activity_records"("clientId");
CREATE INDEX IF NOT EXISTS "activity_records_date_idx" ON "activity_records"("date");

-- Create Step Goal History Table
CREATE TABLE IF NOT EXISTS "step_goal_histories" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "stepGoal" INTEGER NOT NULL,
    "effectiveDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "setById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "step_goal_histories_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "step_goal_histories_clientId_idx" ON "step_goal_histories"("clientId");

-- Foreign Keys
ALTER TABLE "client_profiles" DROP CONSTRAINT IF EXISTS "client_profiles_userId_fkey";
ALTER TABLE "client_profiles" ADD CONSTRAINT "client_profiles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "client_profiles" DROP CONSTRAINT IF EXISTS "client_profiles_trainerId_fkey";
ALTER TABLE "client_profiles" ADD CONSTRAINT "client_profiles_trainerId_fkey" FOREIGN KEY ("trainerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "activity_records" DROP CONSTRAINT IF EXISTS "activity_records_clientId_fkey";
ALTER TABLE "activity_records" ADD CONSTRAINT "activity_records_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "client_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "step_goal_histories" DROP CONSTRAINT IF EXISTS "step_goal_histories_clientId_fkey";
ALTER TABLE "step_goal_histories" ADD CONSTRAINT "step_goal_histories_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "client_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

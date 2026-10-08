import { prisma } from '../config/prisma';
import fs from 'fs';
import path from 'path';

async function runMigration() {
  console.log('Applying User Verification migration...');
  const migrationPath = path.join(__dirname, '../../prisma/migrations/20261008000000_add_user_verification/migration.sql');
  const sql = fs.readFileSync(migrationPath, 'utf8');

  // Execute in transactions / queries
  await prisma.$executeRawUnsafe(`
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'UserStatus') THEN
        CREATE TYPE "UserStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED');
      END IF;
    END$$;
  `);
  console.log('Created UserStatus enum.');

  await prisma.$executeRawUnsafe(`
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
  `);
  console.log('Added verification columns to users table.');

  const updatedUsers = await prisma.$executeRawUnsafe(`
    UPDATE "users"
    SET "status" = 'APPROVED',
        "approvedAt" = COALESCE("approvedAt", NOW()),
        "approvedBy" = COALESCE("approvedBy", 'SYSTEM_MIGRATION')
    WHERE "status" = 'PENDING';
  `);
  console.log(`Backfilled existing users to APPROVED: ${updatedUsers} rows updated.`);

  await prisma.$executeRawUnsafe(`
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
  `);
  console.log('Created user_verification_logs table.');

  await prisma.$executeRawUnsafe(`
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
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "user_verification_logs_userId_idx" ON "user_verification_logs"("userId");
  `);
  console.log('Created indices.');

  console.log('Migration completed successfully!');
  await prisma.$disconnect();
}

runMigration().catch((e) => {
  console.error('Migration failed:', e);
  process.exit(1);
});

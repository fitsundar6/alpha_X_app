-- Alpha X Gym PostgreSQL Migration: Remove Attendance Feature
-- Safely drop client_attendances table without affecting any user, workout, nutrition, or progress data.

DROP TABLE IF EXISTS "client_attendances" CASCADE;

-- Migration: Add Foreign Key relation between workout_records.assignmentId and workout_assignments.id
-- Non-destructive: sets assignmentId to NULL if the referenced workout assignment is deleted, preserving workout history.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'workout_records_assignmentId_fkey'
  ) THEN
    ALTER TABLE "workout_records" 
      ADD CONSTRAINT "workout_records_assignmentId_fkey" 
      FOREIGN KEY ("assignmentId") REFERENCES "workout_assignments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END$$;

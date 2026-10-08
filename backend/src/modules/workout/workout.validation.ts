import { z } from 'zod';

export const workoutTypeEnum = z.string().default('Strength');

export const difficultyEnum = z.string().default('Intermediate');

export const setTypeEnum = z.string().default('Working');

export const exerciseInputSchema = z.object({
  id: z.string().optional(),
  exerciseId: z.string().optional().default('ex_general'),
  exerciseName: z.string().optional().default('Exercise'),
  category: z.string().optional().default('General'),
  orderIndex: z.coerce.number().int().default(0),
  supersetTag: z.string().optional().nullable(),
  numberOfSets: z.coerce.number().int().min(1).max(50).default(3),
  targetReps: z.string().optional().default('8–12'),
  targetWeight: z.coerce.number().optional().nullable(),
  restSeconds: z.coerce.number().int().min(0).max(3600).default(90),
  targetRir: z.coerce.number().int().min(0).max(10).optional().nullable().default(2),
  targetRpe: z.coerce.number().min(0).max(10).optional().nullable().default(8.0),
  tempo: z.string().optional().nullable().default('3-1-1-0'),
  setType: z.string().default('Working'),
  exerciseNotes: z.string().optional().nullable(),
  adminInstruction: z.string().optional().nullable(),
});

export const createSessionSchema = z.object({
  id: z.string().optional(),
  title: z.string().min(1, 'Session title is required'),
  workoutType: z.string().default('Strength'),
  targetMuscleGroup: z.string().optional().nullable().default('Full Body'),
  difficulty: z.string().default('Intermediate'),
  estimatedDurationMinutes: z.coerce.number().int().min(1).max(1440).default(45),
  description: z.string().optional().nullable(),
  isActive: z.boolean().default(true),
  startDate: z.string().optional().nullable(),
  endDate: z.string().optional().nullable(),
  recurringSchedule: z.string().optional().nullable(),
  availabilityType: z.string().default('ALL'),
  exercises: z.array(exerciseInputSchema).optional().default([]),
});

export const updateSessionSchema = createSessionSchema.partial().extend({
  exercises: z.array(exerciseInputSchema).optional(),
});

export const assignSessionSchema = z.object({
  assignmentType: z.enum(['ALL', 'SELECTED', 'INDIVIDUAL']),
  clientIds: z.array(z.string()).optional().default([]),
  individualClientId: z.string().optional().nullable(),
  isRecommended: z.boolean().default(false),
});

export const workoutSetRecordSchema = z.object({
  setNumber: z.number().int().min(1),
  setType: setTypeEnum.default('Working'),
  targetReps: z.string().optional().nullable(),
  targetWeight: z.number().optional().nullable(),
  actualWeight: z.number().optional().nullable(),
  actualReps: z.number().int().min(0).optional().nullable(),
  actualRir: z.number().int().min(0).max(5).optional().nullable(),
  actualRpe: z.number().min(1).max(10).optional().nullable(),
  tempo: z.string().optional().nullable(),
  isCompleted: z.boolean().default(false),
  completedAt: z.string().datetime().optional().nullable(),
  notes: z.string().optional().nullable(),
});

export const workoutExerciseRecordSchema = z.object({
  exerciseId: z.string(),
  exerciseName: z.string(),
  orderIndex: z.number().int().default(0),
  supersetTag: z.string().optional().nullable(),
  isSkipped: z.boolean().default(false),
  skipReason: z.string().optional().nullable(),
  clientNote: z.string().optional().nullable(),
  adminNote: z.string().optional().nullable(),
  sets: z.array(workoutSetRecordSchema).default([]),
});

export const createWorkoutRecordSchema = z.object({
  sessionId: z.string().optional().nullable(),
  sessionTitle: z.string().min(1),
  workoutType: z.string().default('Strength'),
  startedAt: z.string().datetime(),
  completedAt: z.string().datetime().optional().nullable(),
  durationSeconds: z.number().int().min(0).default(0),
  totalVolume: z.number().nonnegative().default(0),
  completedSetsCount: z.number().int().min(0).default(0),
  skippedSetsCount: z.number().int().min(0).default(0),
  averageRpe: z.number().optional().nullable(),
  averageRir: z.number().optional().nullable(),
  isCompleted: z.boolean().default(true),
  personalRecords: z.array(z.any()).optional().default([]),
  notes: z.string().optional().nullable(),
  exerciseRecords: z.array(workoutExerciseRecordSchema).min(1),
});

export const setCompletionSchema = z.object({
  sessionId: z.string().optional(),
  exerciseId: z.string().min(1, 'exerciseId is required'),
  setNumber: z.coerce.number().int().min(1, 'setNumber must be at least 1'),
  isCompleted: z.boolean(),
  actualWeight: z.coerce.number().optional().nullable(),
  actualReps: z.coerce.number().int().min(0).optional().nullable(),
  actualRir: z.coerce.number().int().min(0).max(10).optional().nullable(),
  actualRpe: z.coerce.number().min(0).max(10).optional().nullable(),
  tempo: z.string().optional().nullable(),
});

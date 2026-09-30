import { z } from 'zod';

export const workoutTypeEnum = z.enum([
  'Strength',
  'Hypertrophy',
  'Full Body',
  'Conditioning',
  'HIIT',
  'Cardio',
  'Mobility',
]);

export const difficultyEnum = z.enum([
  'Beginner',
  'Intermediate',
  'Advanced',
]);

export const setTypeEnum = z.enum([
  'Warm-up',
  'Working',
  'Failure',
  'Drop set',
  'Rest-pause',
]);

export const exerciseInputSchema = z.object({
  id: z.string().optional(),
  exerciseId: z.string().min(1, 'Exercise ID is required'),
  exerciseName: z.string().min(1, 'Exercise name is required'),
  category: z.string().default('General'),
  orderIndex: z.number().int().min(0).default(0),
  supersetTag: z.string().optional().nullable(),
  numberOfSets: z.number().int().min(1).max(20).default(3),
  targetReps: z.string().min(1).default('8–12'),
  targetWeight: z.number().nonnegative().optional().nullable(),
  restSeconds: z.number().int().min(0).max(600).default(90),
  targetRir: z.number().int().min(0).max(5).optional().nullable().default(2),
  targetRpe: z.number().min(1).max(10).optional().nullable().default(8.0),
  tempo: z.string().optional().nullable().default('3-1-1-0'),
  setType: setTypeEnum.default('Working'),
  exerciseNotes: z.string().optional().nullable(),
  adminInstruction: z.string().optional().nullable(),
});

export const createSessionSchema = z.object({
  title: z.string().min(2, 'Session title must be at least 2 characters'),
  workoutType: workoutTypeEnum.default('Strength'),
  targetMuscleGroup: z.string().min(2, 'Target muscle group is required'),
  difficulty: difficultyEnum.default('Intermediate'),
  estimatedDurationMinutes: z.number().int().min(5).max(300).default(45),
  description: z.string().optional().nullable(),
  isActive: z.boolean().default(true),
  startDate: z.string().datetime().optional().nullable(),
  endDate: z.string().datetime().optional().nullable(),
  recurringSchedule: z.string().optional().nullable(),
  availabilityType: z.enum(['ALL', 'SELECTED', 'INDIVIDUAL']).default('ALL'),
  exercises: z.array(exerciseInputSchema).min(1, 'At least 1 exercise is required in a session'),
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

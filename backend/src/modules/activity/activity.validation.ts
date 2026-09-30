import { z } from 'zod';

export const syncActivityRecordSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be formatted as YYYY-MM-DD'),
  steps: z.number().int().min(0, 'Steps cannot be negative'),
  stepGoal: z.number().int().min(100, 'Step goal must be at least 100'),
  cardioMinutes: z.number().int().min(0).optional().default(0),
  caloriesBurned: z.number().min(0).optional().default(0),
  distanceMeters: z.number().min(0).optional().default(0),
  isGoalAchieved: z.boolean().optional(),
});

export const syncActivityPayloadSchema = z.object({
  clientId: z.string().optional(), // Client may provide, but server strictly overrides with req.user.id
  records: z.array(syncActivityRecordSchema).min(1, 'At least one activity record required for sync'),
});

export const updateStepGoalSchema = z.object({
  stepGoal: z.number().int().min(1000, 'Minimum step goal is 1,000 steps').max(50000, 'Maximum step goal is 50,000 steps'),
});

export type SyncActivityInput = z.infer<typeof syncActivityPayloadSchema>;
export type UpdateStepGoalInput = z.infer<typeof updateStepGoalSchema>;

/**
 * Alpha X AI — Tool: search_exercise_library
 * Phase 7 — AI Exercise Library Retrieval & Split Alignment
 *
 * Enables Gemini and AI Coach to query verified exercises from the
 * 273-exercise Alpha X Gym database (prisma.exercise).
 */

import { ToolDefinition, ToolPermission, ToolExecutionContext } from '../../tool.types';
import { prisma } from '../../../../../config/prisma';
import { workoutIntentService, WorkoutSplitType } from '../../../workout_intent.service';

export interface SearchExerciseLibraryInput {
  split?: string;               // CHEST, PULL, LEG, PUSH, FULL_BODY
  bodyPart?: string;            // Chest, Back, Shoulders, Quadriceps, Hamstrings, Glutes, Calves, Biceps, Triceps, Core
  query?: string;               // Keyword search (e.g. "press", "row", "squat", "curl")
  category?: string;            // Strength, Hypertrophy, Cardio
  equipment?: string;           // Barbell, Dumbbell, Cable, Machine, Bodyweight
  isCompound?: boolean;         // Heavy multi-joint movements
  isIsolation?: boolean;        // Single-joint accessories
  limit?: number;               // Max number of exercises to return (default: 15)
  clientProfileId?: string;     // If provided, prioritizes exercises not recently proposed for anti-repetition
}

export const searchExerciseLibraryTool: ToolDefinition<SearchExerciseLibraryInput> = {
  name: 'search_exercise_library',
  description:
    'Searches and retrieves verified exercises from the real Alpha X Gym exercise catalog. ' +
    'Use this tool to find real exercise IDs, accurate body parts, movement categories, and equipment ' +
    'for specific splits (Chest Day, Pull Day, Leg Day, Push Day, Full Body) before proposing a workout plan. ' +
    'Never invent exercise IDs or generate exercises that do not exist in the catalog.',
  category: 'READ',
  permission: ToolPermission.READ_SYSTEM,
  inputSchema: {
    type: 'object',
    properties: {
      split: {
        type: 'string',
        description: 'Target workout split or category, e.g. "UPPER_LOWER", "PUSH_PULL_LEGS", "BRO_SPLIT", "FULL_BODY", "PUSH", "PULL", "LEG", "CHEST", or "GENERAL"',
      },
      bodyPart: {
        type: 'string',
        description: 'Specific body part: "Chest", "Back", "Shoulders", "Quadriceps", "Hamstrings", "Glutes", "Calves", "Biceps", "Triceps", "Core", "Full Body"',
      },
      query: {
        type: 'string',
        description: 'Keyword search for exercise name or target muscle (e.g. "bench", "lat pulldown", "squat")',
        maxLength: 100,
      },
      category: {
        type: 'string',
        description: 'Exercise category: "Strength", "Hypertrophy", "Cardio", etc.',
      },
      equipment: {
        type: 'string',
        description: 'Equipment type: "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight"',
      },
      isCompound: {
        type: 'boolean',
        description: 'Filter for compound multi-joint movements',
      },
      isIsolation: {
        type: 'boolean',
        description: 'Filter for isolation / accessory movements',
      },
      limit: {
        type: 'number',
        description: 'Maximum number of exercises to return (1-30, default: 15)',
      },
      clientProfileId: {
        type: 'string',
        description: 'Optional client profile ID to de-duplicate recently used exercises for progressive variation',
      },
    },
  },
  handler: async (args: SearchExerciseLibraryInput, _context: ToolExecutionContext) => {
    try {
      const limit = Math.min(30, Math.max(1, Number(args.limit) || 15));

      // 1. If a split is specified, use split-aware balanced retrieval
      if (args.split && args.split !== 'GENERAL') {
        const splitResult = workoutIntentService.detectSplit(`${args.split} day`);
        const exercises = await workoutIntentService.getBalancedExercisesForSplit(splitResult, {
          clientProfileId: args.clientProfileId,
          count: limit,
        });

        return {
          success: true,
          source: 'ALPHA_X_DATABASE',
          split: splitResult.split,
          targetMuscleGroup: splitResult.targetMuscleGroup,
          totalFound: exercises.length,
          exercises: exercises.map((e) => ({
            exerciseId: e.id,
            name: e.name,
            category: e.category,
            bodyPart: e.bodyPart,
            equipment: e.equipment,
            isCompound: e.isCompound,
            isIsolation: e.isIsolation,
            difficulty: e.difficulty,
          })),
        };
      }

      // 2. Direct filtered database query on prisma.exercise
      const where: any = { isActive: true };

      if (args.bodyPart && args.bodyPart !== 'ALL') {
        where.bodyPart = { equals: args.bodyPart, mode: 'insensitive' };
      }

      if (args.category) {
        where.category = { equals: args.category, mode: 'insensitive' };
      }

      if (args.equipment) {
        where.equipment = { contains: args.equipment, mode: 'insensitive' };
      }

      if (typeof args.isCompound === 'boolean') {
        where.isCompound = args.isCompound;
      }

      if (typeof args.isIsolation === 'boolean') {
        where.isIsolation = args.isIsolation;
      }

      if (args.query && args.query.trim()) {
        const q = args.query.trim();
        where.OR = [
          { name: { contains: q, mode: 'insensitive' } },
          { normalizedName: { contains: q.toLowerCase(), mode: 'insensitive' } },
          { primaryMuscles: { hasSome: [q] } },
        ];
      }

      const exercises = await prisma.exercise.findMany({
        where,
        take: limit,
        orderBy: [{ isCompound: 'desc' }, { name: 'asc' }],
        select: {
          id: true,
          name: true,
          category: true,
          bodyPart: true,
          equipment: true,
          isCompound: true,
          isIsolation: true,
          difficulty: true,
          primaryMuscles: true,
          secondaryMuscles: true,
        },
      });

      return {
        success: true,
        source: 'ALPHA_X_DATABASE',
        totalFound: exercises.length,
        exercises: exercises.map((e) => ({
          exerciseId: e.id,
          name: e.name,
          category: e.category,
          bodyPart: e.bodyPart,
          equipment: e.equipment,
          isCompound: e.isCompound,
          isIsolation: e.isIsolation,
          difficulty: e.difficulty,
          primaryMuscles: e.primaryMuscles,
          secondaryMuscles: e.secondaryMuscles,
        })),
      };
    } catch (err: any) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: 'DATABASE_ERROR',
        message: `Failed to search exercise library: ${err?.message || String(err)}`,
        exercises: [],
      };
    }
  },
  enabled: true,
};

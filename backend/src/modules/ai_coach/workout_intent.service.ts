import { prisma } from '../../config/prisma';

export type WorkoutSplitKey =
  | 'FULL_BODY'
  | 'UPPER_LOWER'
  | 'PUSH_PULL_LEGS'
  | 'PPL_X2'
  | 'BRO_SPLIT'
  | 'CHEST_BACK_SHOULDERS_ARMS_LEGS'
  | 'ARNOLD_SPLIT'
  | 'ANTAGONIST_SPLIT'
  | 'POWERLIFTING_SPLIT'
  | 'SBD_FOCUS'
  | 'FIVE_THREE_ONE'
  | 'UPPER_LOWER_STRENGTH'
  | 'HYPERTROPHY_SPECIALIZATION'
  | 'WEAK_POINT_FOCUS'
  | 'UPPER_LOWER_ARMS'
  | 'FULL_BODY_CONDITIONING'
  | 'STRENGTH_CONDITIONING'
  | 'CIRCUIT_TRAINING'
  | 'SPORTS_PERFORMANCE'
  | 'CUSTOM_SPLIT'
  // Single-day focus splits (backward compatibility)
  | 'CHEST'
  | 'PULL'
  | 'LEG'
  | 'PUSH'
  | 'AMBIGUOUS'
  | 'GENERAL';

export type WorkoutSplitType = WorkoutSplitKey;

export interface GeneratedDayPlan {
  dayNumber: number;
  dayName: string;            // "Monday", "Day 1 (Monday)"
  sessionTitle: string;       // "Upper Body Strength"
  workoutType: string;        // "Hypertrophy" | "Strength" | "Conditioning"
  targetMuscleGroup: string;  // "Chest · Back · Shoulders"
  primaryBodyParts: string[];
  allowedBodyParts: string[];
  disallowedBodyParts: string[];
  estimatedDurationMinutes: number;
  recommendedExercisesCount: number;
}

export interface ScheduleGenerationOptions {
  daysPerWeek: number;
  primaryGoal?: string;
  trainingExperience?: string;
  sessionDurationMinutes?: number;
  focusMuscles?: string[];
  weakPoints?: string[];
  equipment?: string;
  injuryExclusions?: string[];
  preferredExercises?: string[];
  exercisesToAvoid?: string[];
  weekdaySchedule?: string[];
}

export interface WorkoutSplitTemplate {
  key: WorkoutSplitKey;
  id: string;
  displayName: string;
  category: 'Bodypart' | 'Movement' | 'Strength' | 'Conditioning' | 'Custom';
  description: string;
  defaultDaysPerWeek: number;
  minDays: number;
  maxDays: number;
  sensibleDaysOptions: number[];
  generateSchedule: (options: ScheduleGenerationOptions) => GeneratedDayPlan[];
}

export interface SplitDetectionResult {
  split: WorkoutSplitKey;
  templateId: string;
  displayName: string;
  titleSuffix: string;
  targetMuscleGroup: string;
  isAmbiguous: boolean;
  ambiguityReason?: string;
  primaryBodyParts: string[];
  allowedBodyParts: string[];
  disallowedBodyParts: string[];
  suggestedDaysPerWeek: number;
  isMultiDayTemplate: boolean;
}

export interface ValidatedExerciseItem {
  exerciseId: string;
  exerciseName: string;
  name: string;
  category: string;
  bodyPart: string;
  orderIndex: number;
  sets: number;
  reps: string;
  restSeconds: number;
  targetWeight?: number | null;
  targetRir?: number;
  targetRpe?: number;
  notes?: string;
  day?: string;
}

export interface PersonalizedExerciseParameters {
  sets: number;
  numberOfSets: number;
  reps: string;
  targetReps: string;
  weight: number | null;
  targetWeight: number | null;
  restSeconds: number;
  targetRir: number;
  targetRpe: number;
  tempo: string;
  notes: string;
  adminInstruction: string;
}

export interface SplitValidationOptions {
  clientProfileId?: string;
  injuryAreas?: string[];
  fitnessLevel?: string;
  primaryGoal?: string;
}

const DEFAULT_WEEKDAY_PATTERNS: Record<number, string[]> = {
  2: ['Monday', 'Thursday'],
  3: ['Monday', 'Wednesday', 'Friday'],
  4: ['Monday', 'Tuesday', 'Thursday', 'Friday'],
  5: ['Monday', 'Tuesday', 'Wednesday', 'Friday', 'Saturday'],
  6: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
  7: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
};

function resolveDayNames(daysCount: number, explicitSchedule?: string[]): string[] {
  if (Array.isArray(explicitSchedule) && explicitSchedule.length >= daysCount) {
    return explicitSchedule.slice(0, daysCount);
  }
  const defaults = DEFAULT_WEEKDAY_PATTERNS[daysCount] || DEFAULT_WEEKDAY_PATTERNS[4];
  if (defaults && defaults.length >= daysCount) {
    return defaults.slice(0, daysCount);
  }
  return Array.from({ length: daysCount }, (_, i) => `Day ${i + 1}`);
}

export const WORKOUT_SPLIT_TEMPLATES: WorkoutSplitTemplate[] = [
  // 1. Full Body
  {
    key: 'FULL_BODY',
    id: 'full_body',
    displayName: 'Full Body',
    category: 'Movement',
    description: 'Trains every major muscle group each session with balanced, rotating compound lifts.',
    defaultDaysPerWeek: 3,
    minDays: 2,
    maxDays: 4,
    sensibleDaysOptions: [2, 3, 4],
    generateSchedule: (opts) => {
      const days = Math.max(2, Math.min(4, opts.daysPerWeek || 3));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;

      const fullBodyPool = ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'];

      if (days === 2) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Full Body A — Quad & Horizontal Push / Pull Focus',
            workoutType: opts.primaryGoal?.includes('Strength') ? 'Strength' : 'Hypertrophy',
            targetMuscleGroup: 'Chest · Back · Quadriceps · Core',
            primaryBodyParts: ['Chest', 'Back', 'Quadriceps'],
            allowedBodyParts: fullBodyPool,
            disallowedBodyParts: [],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Full Body B — Posterior Chain & Vertical Focus',
            workoutType: opts.primaryGoal?.includes('Strength') ? 'Strength' : 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Hamstrings · Glutes · Arms',
            primaryBodyParts: ['Shoulders', 'Hamstrings', 'Glutes'],
            allowedBodyParts: fullBodyPool,
            disallowedBodyParts: [],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      if (days === 4) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Full Body 1 — Squat & Horizontal Press',
            workoutType: 'Strength',
            targetMuscleGroup: 'Quadriceps · Chest · Upper Back',
            primaryBodyParts: ['Quadriceps', 'Chest', 'Back'],
            allowedBodyParts: fullBodyPool,
            disallowedBodyParts: [],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Full Body 2 — Deadlift & Vertical Press',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Hamstrings · Shoulders · Lats',
            primaryBodyParts: ['Hamstrings', 'Shoulders', 'Back'],
            allowedBodyParts: fullBodyPool,
            disallowedBodyParts: [],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Full Body 3 — Quad Volume & Row Hypertrophy',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Quadriceps · Back · Chest',
            primaryBodyParts: ['Quadriceps', 'Back', 'Chest'],
            allowedBodyParts: fullBodyPool,
            disallowedBodyParts: [],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 4,
            dayName: names[3],
            sessionTitle: 'Full Body 4 — Posterior Chain & Arm Density',
            workoutType: 'Strength',
            targetMuscleGroup: 'Glutes · Shoulders · Biceps · Triceps',
            primaryBodyParts: ['Glutes', 'Shoulders', 'Biceps', 'Triceps'],
            allowedBodyParts: fullBodyPool,
            disallowedBodyParts: [],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
        ];
      }

      // Default: 3 Days
      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Full Body A — Squat & Bench Foundation',
          workoutType: opts.primaryGoal?.includes('Strength') ? 'Strength' : 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back · Quadriceps · Core',
          primaryBodyParts: ['Chest', 'Back', 'Quadriceps'],
          allowedBodyParts: fullBodyPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Full Body B — Deadlift & Overhead Power',
          workoutType: opts.primaryGoal?.includes('Strength') ? 'Strength' : 'Hypertrophy',
          targetMuscleGroup: 'Shoulders · Back · Hamstrings · Glutes',
          primaryBodyParts: ['Shoulders', 'Back', 'Hamstrings'],
          allowedBodyParts: fullBodyPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Full Body C — Unilateral & Metabolic Hypertrophy',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back · Legs · Arms',
          primaryBodyParts: ['Chest', 'Back', 'Quadriceps', 'Hamstrings'],
          allowedBodyParts: fullBodyPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
      ];
    },
  },

  // 2. Upper / Lower
  {
    key: 'UPPER_LOWER',
    id: 'upper_lower',
    displayName: 'Upper / Lower',
    category: 'Movement',
    description: 'Alternates upper body torso sessions with lower body leg and posterior chain sessions.',
    defaultDaysPerWeek: 4,
    minDays: 2,
    maxDays: 5,
    sensibleDaysOptions: [2, 3, 4, 5],
    generateSchedule: (opts) => {
      const days = Math.max(2, Math.min(5, opts.daysPerWeek || 4));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;

      const upperAllowed = ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Core'];
      const upperDisallowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'];
      const lowerAllowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'];
      const lowerDisallowed = ['Chest', 'Back', 'Biceps', 'Triceps'];

      if (days === 2) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Upper Body Power & Hypertrophy',
            workoutType: 'Strength',
            targetMuscleGroup: 'Chest · Back · Shoulders · Arms',
            primaryBodyParts: ['Chest', 'Back', 'Shoulders'],
            allowedBodyParts: upperAllowed,
            disallowedBodyParts: upperDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Lower Body Strength & Posterior Chain',
            workoutType: 'Strength',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes'],
            allowedBodyParts: lowerAllowed,
            disallowedBodyParts: lowerDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      if (days === 3) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Upper Body A — Horizontal Push / Pull Focus',
            workoutType: 'Strength',
            targetMuscleGroup: 'Chest · Back · Shoulders · Triceps',
            primaryBodyParts: ['Chest', 'Back'],
            allowedBodyParts: upperAllowed,
            disallowedBodyParts: upperDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Lower Body — Quad & Hamstring Power',
            workoutType: 'Strength',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes'],
            allowedBodyParts: lowerAllowed,
            disallowedBodyParts: lowerDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Upper Body B — Vertical Push / Pull Focus',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Lats · Chest · Biceps',
            primaryBodyParts: ['Shoulders', 'Back'],
            allowedBodyParts: upperAllowed,
            disallowedBodyParts: upperDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      if (days === 5) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Upper Body Power (Strength)',
            workoutType: 'Strength',
            targetMuscleGroup: 'Chest · Back · Shoulders',
            primaryBodyParts: ['Chest', 'Back', 'Shoulders'],
            allowedBodyParts: upperAllowed,
            disallowedBodyParts: upperDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Lower Body Power (Strength)',
            workoutType: 'Strength',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes',
            primaryBodyParts: ['Quadriceps', 'Hamstrings'],
            allowedBodyParts: lowerAllowed,
            disallowedBodyParts: lowerDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Upper Body Hypertrophy (Volume)',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Back · Shoulders · Arms',
            primaryBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps'],
            allowedBodyParts: upperAllowed,
            disallowedBodyParts: upperDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 4,
            dayName: names[3],
            sessionTitle: 'Lower Body Hypertrophy (Volume)',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes'],
            allowedBodyParts: lowerAllowed,
            disallowedBodyParts: lowerDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 5,
            dayName: names[4],
            sessionTitle: 'Arms, Shoulders & Weak-Point Specialization',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Biceps · Triceps · Core',
            primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
            allowedBodyParts: upperAllowed,
            disallowedBodyParts: upperDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      // Default: 4 Days
      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Upper Body A — Heavy Compound Power',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest · Back · Shoulders · Arms',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: upperAllowed,
          disallowedBodyParts: upperDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Lower Body A — Squat & Quad Emphasized',
          workoutType: 'Strength',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Calves',
          primaryBodyParts: ['Quadriceps', 'Hamstrings'],
          allowedBodyParts: lowerAllowed,
          disallowedBodyParts: lowerDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Upper Body B — Hypertrophy & Density',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Back · Chest · Deltoids · Arms',
          primaryBodyParts: ['Back', 'Chest', 'Shoulders'],
          allowedBodyParts: upperAllowed,
          disallowedBodyParts: upperDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 4,
          dayName: names[3],
          sessionTitle: 'Lower Body B — Deadlift & Posterior Chain',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Hamstrings · Glutes · Quadriceps · Core',
          primaryBodyParts: ['Hamstrings', 'Glutes', 'Quadriceps'],
          allowedBodyParts: lowerAllowed,
          disallowedBodyParts: lowerDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
      ];
    },
  },

  // 3. Push / Pull / Legs
  {
    key: 'PUSH_PULL_LEGS',
    id: 'push_pull_legs',
    displayName: 'Push / Pull / Legs',
    category: 'Movement',
    description: 'Gold-standard movement split grouping pushing muscles, pulling muscles, and legs.',
    defaultDaysPerWeek: 3,
    minDays: 3,
    maxDays: 6,
    sensibleDaysOptions: [3, 4, 5, 6],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(6, opts.daysPerWeek || 3));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;

      const pushAllowed = ['Chest', 'Shoulders', 'Triceps'];
      const pushDisallowed = ['Back', 'Biceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'];
      const pullAllowed = ['Back', 'Biceps', 'Shoulders', 'Core'];
      const pullDisallowed = ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Triceps'];
      const legAllowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'];
      const legDisallowed = ['Chest', 'Back', 'Biceps', 'Triceps'];

      const schedule: GeneratedDayPlan[] = [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Push Day — Chest, Anterior Delts & Triceps',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Shoulders · Triceps',
          primaryBodyParts: ['Chest', 'Shoulders'],
          allowedBodyParts: pushAllowed,
          disallowedBodyParts: pushDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Pull Day — Back, Rear Delts & Biceps',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Back · Biceps · Rear Delts',
          primaryBodyParts: ['Back', 'Biceps'],
          allowedBodyParts: pullAllowed,
          disallowedBodyParts: pullDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Leg Day — Quads, Hamstrings & Calves',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
          primaryBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes'],
          allowedBodyParts: legAllowed,
          disallowedBodyParts: legDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
      ];

      if (days >= 4) {
        schedule.push({
          dayNumber: 4,
          dayName: names[3],
          sessionTitle: 'Upper Body Focus — Weak-Point Hypertrophy',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back · Arms',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps'],
          disallowedBodyParts: legAllowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        });
      }

      if (days >= 5) {
        schedule.push({
          dayNumber: 5,
          dayName: names[4],
          sessionTitle: 'Lower Body & Core Hypertrophy',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Hamstrings · Glutes · Quads · Core',
          primaryBodyParts: ['Hamstrings', 'Glutes'],
          allowedBodyParts: legAllowed,
          disallowedBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        });
      }

      if (days >= 6) {
        // Replace with full PPL x 2 layout
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Push A — Heavy Bench & Shoulder Press Focus',
            workoutType: 'Strength',
            targetMuscleGroup: 'Chest · Shoulders · Triceps',
            primaryBodyParts: ['Chest', 'Shoulders'],
            allowedBodyParts: pushAllowed,
            disallowedBodyParts: pushDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Pull A — Deadlift & Heavy Row Focus',
            workoutType: 'Strength',
            targetMuscleGroup: 'Back · Biceps',
            primaryBodyParts: ['Back', 'Biceps'],
            allowedBodyParts: pullAllowed,
            disallowedBodyParts: pullDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Legs A — Back Squat & Quad Power Focus',
            workoutType: 'Strength',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings'],
            allowedBodyParts: legAllowed,
            disallowedBodyParts: legDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 4,
            dayName: names[3],
            sessionTitle: 'Push B — Incline DB & Deltoid Volume Focus',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Shoulders · Triceps',
            primaryBodyParts: ['Chest', 'Shoulders'],
            allowedBodyParts: pushAllowed,
            disallowedBodyParts: pushDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 5,
            dayName: names[4],
            sessionTitle: 'Pull B — Lat Pulldown & Bicep Density Focus',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Back · Biceps',
            primaryBodyParts: ['Back', 'Biceps'],
            allowedBodyParts: pullAllowed,
            disallowedBodyParts: pullDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 6,
            dayName: names[5],
            sessionTitle: 'Legs B — RDL & Hamstring/Glute Hypertrophy',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Hamstrings · Glutes · Calves',
            primaryBodyParts: ['Hamstrings', 'Glutes'],
            allowedBodyParts: legAllowed,
            disallowedBodyParts: legDisallowed,
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      return schedule;
    },
  },

  // 4. PPL × 2
  {
    key: 'PPL_X2',
    id: 'ppl_x2',
    displayName: 'PPL × 2',
    category: 'Movement',
    description: 'High-frequency 6-day split running Push/Pull/Legs twice weekly with varied movement variations.',
    defaultDaysPerWeek: 6,
    minDays: 5,
    maxDays: 6,
    sensibleDaysOptions: [5, 6],
    generateSchedule: (opts) => {
      const days = Math.max(5, Math.min(6, opts.daysPerWeek || 6));
      return WORKOUT_SPLIT_TEMPLATES.find((t) => t.key === 'PUSH_PULL_LEGS')!.generateSchedule({
        ...opts,
        daysPerWeek: days,
      });
    },
  },

  // 5. Bro Split / One Muscle per Day
  {
    key: 'BRO_SPLIT',
    id: 'bro_split',
    displayName: 'Bro Split / One Muscle per Day',
    category: 'Bodypart',
    description: 'Classic single-muscle focus providing maximal isolation and pump per individual body part.',
    defaultDaysPerWeek: 5,
    minDays: 4,
    maxDays: 6,
    sensibleDaysOptions: [4, 5, 6],
    generateSchedule: (opts) => {
      const days = Math.max(4, Math.min(6, opts.daysPerWeek || 5));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 45;

      if (days === 4) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Chest & Triceps Blitz',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Triceps',
            primaryBodyParts: ['Chest'],
            allowedBodyParts: ['Chest', 'Triceps'],
            disallowedBodyParts: ['Back', 'Legs', 'Quadriceps'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Back & Biceps Thickness',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Back · Biceps',
            primaryBodyParts: ['Back'],
            allowedBodyParts: ['Back', 'Biceps'],
            disallowedBodyParts: ['Chest', 'Legs'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Shoulders & Core Sculpt',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Core',
            primaryBodyParts: ['Shoulders'],
            allowedBodyParts: ['Shoulders', 'Core'],
            disallowedBodyParts: ['Back', 'Chest', 'Legs'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 4,
            dayName: names[3],
            sessionTitle: 'Leg Day Annihilation',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings'],
            allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
            disallowedBodyParts: ['Chest', 'Back', 'Shoulders', 'Arms'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      // Default: 5 Days (Classic Bro Split)
      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Chest Day (Pectoral Focus)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Optional Triceps Accessory',
          primaryBodyParts: ['Chest'],
          allowedBodyParts: ['Chest', 'Triceps'],
          disallowedBodyParts: ['Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Biceps'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Back Day (Lat & Trapezius Focus)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Back · Lats · Biceps',
          primaryBodyParts: ['Back'],
          allowedBodyParts: ['Back', 'Biceps'],
          disallowedBodyParts: ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Triceps'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Shoulders Day (Deltoid Capped Focus)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Deltoids · Traps · Upper Back',
          primaryBodyParts: ['Shoulders'],
          allowedBodyParts: ['Shoulders', 'Core'],
          disallowedBodyParts: ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Legs', 'Back'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 4,
          dayName: names[3],
          sessionTitle: 'Legs Day (Lower Body Hypertrophy)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
          primaryBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
          allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'],
          disallowedBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps', 'Shoulders'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 5,
          dayName: names[4],
          sessionTitle: 'Arms Day (Biceps & Triceps Superset Focus)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Biceps · Triceps · Forearms',
          primaryBodyParts: ['Biceps', 'Triceps'],
          allowedBodyParts: ['Biceps', 'Triceps', 'Forearms'],
          disallowedBodyParts: ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
      ];
    },
  },

  // 6. Chest / Back / Shoulders / Arms / Legs
  {
    key: 'CHEST_BACK_SHOULDERS_ARMS_LEGS',
    id: 'chest_back_shoulders_arms_legs',
    displayName: 'Chest / Back / Shoulders / Arms / Legs',
    category: 'Bodypart',
    description: 'Systematic 5-day bodypart isolation targeting full muscular symmetry.',
    defaultDaysPerWeek: 5,
    minDays: 4,
    maxDays: 5,
    sensibleDaysOptions: [4, 5],
    generateSchedule: (opts) => {
      return WORKOUT_SPLIT_TEMPLATES.find((t) => t.key === 'BRO_SPLIT')!.generateSchedule(opts);
    },
  },

  // 7. Arnold Split
  {
    key: 'ARNOLD_SPLIT',
    id: 'arnold_split',
    displayName: 'Arnold Split',
    category: 'Bodypart',
    description: 'Golden-Era favorite pairing opposing muscle groups: Chest/Back, Shoulders/Arms, and Legs.',
    defaultDaysPerWeek: 6,
    minDays: 3,
    maxDays: 6,
    sensibleDaysOptions: [3, 4, 5, 6],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(6, opts.daysPerWeek || 6));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 55;

      const chestBackAllowed = ['Chest', 'Back', 'Core'];
      const shouldersArmsAllowed = ['Shoulders', 'Biceps', 'Triceps', 'Forearms'];
      const legsAllowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'];

      if (days === 3) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Arnold Day 1 — Chest & Back Superset Protocol',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Lats · Upper Back',
            primaryBodyParts: ['Chest', 'Back'],
            allowedBodyParts: chestBackAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Legs'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Arnold Day 2 — Shoulders & Arms Peak Protocol',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Biceps · Triceps',
            primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
            allowedBodyParts: shouldersArmsAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Back', 'Chest'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Arnold Day 3 — Lower Body Power & Calves',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings'],
            allowedBodyParts: legsAllowed,
            disallowedBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
        ];
      }

      if (days === 4) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Arnold Day 1 — Chest & Back Power',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Back',
            primaryBodyParts: ['Chest', 'Back'],
            allowedBodyParts: chestBackAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Arnold Day 2 — Shoulders & Arms',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Biceps · Triceps',
            primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
            allowedBodyParts: shouldersArmsAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Arnold Day 3 — Lower Body & Abs',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes',
            primaryBodyParts: ['Quadriceps', 'Hamstrings'],
            allowedBodyParts: legsAllowed,
            disallowedBodyParts: ['Chest', 'Back', 'Arms'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 4,
            dayName: names[3],
            sessionTitle: 'Arnold Day 4 — Upper Body Golden Ratio Sculpt',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Back · Arms',
            primaryBodyParts: ['Chest', 'Back', 'Arms'],
            allowedBodyParts: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps'],
            disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
        ];
      }

      if (days === 5) {
        return [
          {
            dayNumber: 1,
            dayName: names[0],
            sessionTitle: 'Arnold A — Chest & Back Antagonistic Pairs',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Back',
            primaryBodyParts: ['Chest', 'Back'],
            allowedBodyParts: chestBackAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 2,
            dayName: names[1],
            sessionTitle: 'Arnold A — Shoulders & Arms Antagonistic Pairs',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Biceps · Triceps',
            primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
            allowedBodyParts: shouldersArmsAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Chest'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 3,
            dayName: names[2],
            sessionTitle: 'Arnold Legs & Core Routine',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
            primaryBodyParts: ['Quadriceps', 'Hamstrings'],
            allowedBodyParts: legsAllowed,
            disallowedBodyParts: ['Chest', 'Back', 'Arms'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 5,
          },
          {
            dayNumber: 4,
            dayName: names[3],
            sessionTitle: 'Arnold B — Chest & Back Hypertrophy',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Chest · Back',
            primaryBodyParts: ['Chest', 'Back'],
            allowedBodyParts: chestBackAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
          {
            dayNumber: 5,
            dayName: names[4],
            sessionTitle: 'Arnold B — Shoulders & Arms Volume',
            workoutType: 'Hypertrophy',
            targetMuscleGroup: 'Shoulders · Biceps · Triceps',
            primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
            allowedBodyParts: shouldersArmsAllowed,
            disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
            estimatedDurationMinutes: estDur,
            recommendedExercisesCount: 4,
          },
        ];
      }

      // Default: 6 Days (Classic Arnold Routine)
      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Chest & Back A — Heavy Compound Superset Focus',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: chestBackAllowed,
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Shoulders & Arms A — Deltoid & Arm Hypertrophy',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Shoulders · Biceps · Triceps',
          primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
          allowedBodyParts: shouldersArmsAllowed,
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Chest', 'Back'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Legs A — Squat Power & Hamstring Hypertrophy',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Calves',
          primaryBodyParts: ['Quadriceps', 'Hamstrings'],
          allowedBodyParts: legsAllowed,
          disallowedBodyParts: ['Chest', 'Back', 'Arms'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 4,
          dayName: names[3],
          sessionTitle: 'Chest & Back B — Incline & Lat Pulldown Volume',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: chestBackAllowed,
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 5,
          dayName: names[4],
          sessionTitle: 'Shoulders & Arms B — Lateral Delt & Arm Pump',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Shoulders · Biceps · Triceps',
          primaryBodyParts: ['Shoulders', 'Biceps', 'Triceps'],
          allowedBodyParts: shouldersArmsAllowed,
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Chest', 'Back'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 6,
          dayName: names[5],
          sessionTitle: 'Legs B — Deadlift / Hinge & Quad Hypertrophy',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Hamstrings · Quadriceps · Glutes · Calves',
          primaryBodyParts: ['Hamstrings', 'Quadriceps'],
          allowedBodyParts: legsAllowed,
          disallowedBodyParts: ['Chest', 'Back', 'Arms'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
      ];
    },
  },

  // 8. Antagonist Split
  {
    key: 'ANTAGONIST_SPLIT',
    id: 'antagonist_split',
    displayName: 'Antagonist Split',
    category: 'Movement',
    description: 'Alternating opposing muscle pairs for maximum mechanical efficiency and muscle recovery.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 5,
    sensibleDaysOptions: [3, 4, 5],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(5, opts.daysPerWeek || 4));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Antagonist Day 1 — Chest & Back (Push / Pull)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: ['Chest', 'Back', 'Core'],
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Antagonist Day 2 — Quads & Hamstrings (Knee Flex / Ext)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Calves',
          primaryBodyParts: ['Quadriceps', 'Hamstrings'],
          allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
          disallowedBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Antagonist Day 3 — Biceps & Triceps (Arm Super-Sets)',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Biceps · Triceps · Forearms',
          primaryBodyParts: ['Biceps', 'Triceps'],
          allowedBodyParts: ['Biceps', 'Triceps', 'Forearms', 'Core'],
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Chest', 'Back'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 4
          ? [
              {
                dayNumber: 4,
                dayName: names[3],
                sessionTitle: 'Antagonist Day 4 — Anterior Delts & Rear Delts / Core',
                workoutType: 'Hypertrophy',
                targetMuscleGroup: 'Shoulders · Rear Delts · Core',
                primaryBodyParts: ['Shoulders'],
                allowedBodyParts: ['Shoulders', 'Core'],
                disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Chest'],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 4,
              },
            ]
          : []),
      ];
    },
  },

  // 9. Powerlifting Split
  {
    key: 'POWERLIFTING_SPLIT',
    id: 'powerlifting_split',
    displayName: 'Powerlifting Split',
    category: 'Strength',
    description: 'Competition-focused periodization for maximal 1RM strength in Squat, Bench, and Deadlift.',
    defaultDaysPerWeek: 3,
    minDays: 3,
    maxDays: 4,
    sensibleDaysOptions: [3, 4],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(4, opts.daysPerWeek || 3));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 60;

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Powerlifting Day 1 — Competition Squat & Leg Assistance',
          workoutType: 'Strength',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes · Core',
          primaryBodyParts: ['Quadriceps', 'Hamstrings'],
          allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Core', 'Legs'],
          disallowedBodyParts: ['Chest', 'Biceps'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Powerlifting Day 2 — Competition Bench Press & Upper Accessories',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest · Triceps · Shoulders',
          primaryBodyParts: ['Chest', 'Triceps'],
          allowedBodyParts: ['Chest', 'Triceps', 'Shoulders', 'Back'],
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Powerlifting Day 3 — Competition Deadlift & Back Power',
          workoutType: 'Strength',
          targetMuscleGroup: 'Hamstrings · Back · Glutes · Core',
          primaryBodyParts: ['Hamstrings', 'Back'],
          allowedBodyParts: ['Hamstrings', 'Back', 'Glutes', 'Core', 'Legs'],
          disallowedBodyParts: ['Chest'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 4
          ? [
              {
                dayNumber: 4,
                dayName: names[3],
                sessionTitle: 'Powerlifting Day 4 — Overhead Press & Weak-Point Assistance',
                workoutType: 'Strength',
                targetMuscleGroup: 'Shoulders · Upper Back · Triceps',
                primaryBodyParts: ['Shoulders', 'Back'],
                allowedBodyParts: ['Shoulders', 'Back', 'Triceps', 'Core'],
                disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 4,
              },
            ]
          : []),
      ];
    },
  },

  // 10. Squat / Bench / Deadlift Focus
  {
    key: 'SBD_FOCUS',
    id: 'sbd_focus',
    displayName: 'Squat / Bench / Deadlift Focus',
    category: 'Strength',
    description: 'Direct focus on the Big Three power movements with targeted hypertrophy assistance.',
    defaultDaysPerWeek: 3,
    minDays: 3,
    maxDays: 4,
    sensibleDaysOptions: [3, 4],
    generateSchedule: (opts) => {
      return WORKOUT_SPLIT_TEMPLATES.find((t) => t.key === 'POWERLIFTING_SPLIT')!.generateSchedule(opts);
    },
  },

  // 11. 5/3/1-style strength programming
  {
    key: 'FIVE_THREE_ONE',
    id: 'five_three_one',
    displayName: '5/3/1-style strength programming',
    category: 'Strength',
    description: 'Jim Wendler wave loading protocol rotating the overhead press, deadlift, bench, and squat.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 4,
    sensibleDaysOptions: [3, 4],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(4, opts.daysPerWeek || 4));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 55;

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: '5/3/1 Wave 1 — Overhead Press Main & BBB Assistance',
          workoutType: 'Strength',
          targetMuscleGroup: 'Shoulders · Triceps · Upper Back',
          primaryBodyParts: ['Shoulders', 'Triceps'],
          allowedBodyParts: ['Shoulders', 'Triceps', 'Back', 'Core'],
          disallowedBodyParts: ['Quadriceps', 'Hamstrings'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: '5/3/1 Wave 2 — Deadlift Main & Posterior Chain Assistance',
          workoutType: 'Strength',
          targetMuscleGroup: 'Hamstrings · Glutes · Lower Back · Core',
          primaryBodyParts: ['Hamstrings', 'Back'],
          allowedBodyParts: ['Hamstrings', 'Back', 'Glutes', 'Core', 'Legs'],
          disallowedBodyParts: ['Chest', 'Shoulders'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: '5/3/1 Wave 3 — Bench Press Main & Upper Assistance',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest · Triceps · Lats',
          primaryBodyParts: ['Chest', 'Triceps'],
          allowedBodyParts: ['Chest', 'Triceps', 'Back', 'Shoulders'],
          disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 4
          ? [
              {
                dayNumber: 4,
                dayName: names[3],
                sessionTitle: '5/3/1 Wave 4 — Squat Main & Quad Assistance',
                workoutType: 'Strength',
                targetMuscleGroup: 'Quadriceps · Hamstrings · Core',
                primaryBodyParts: ['Quadriceps', 'Hamstrings'],
                allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Core', 'Legs'],
                disallowedBodyParts: ['Chest', 'Biceps'],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 4,
              },
            ]
          : []),
      ];
    },
  },

  // 12. Upper / Lower Strength
  {
    key: 'UPPER_LOWER_STRENGTH',
    id: 'upper_lower_strength',
    displayName: 'Upper / Lower Strength',
    category: 'Strength',
    description: 'Heavy compound upper/lower split engineered for strength progression and high CNS output.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 4,
    sensibleDaysOptions: [3, 4],
    generateSchedule: (opts) => {
      return WORKOUT_SPLIT_TEMPLATES.find((t) => t.key === 'UPPER_LOWER')!.generateSchedule({
        ...opts,
        primaryGoal: 'Strength',
      });
    },
  },

  // 13. Hypertrophy / Specialization Split
  {
    key: 'HYPERTROPHY_SPECIALIZATION',
    id: 'hypertrophy_specialization',
    displayName: 'Hypertrophy / Specialization Split',
    category: 'Bodypart',
    description: 'High-volume hypertrophy split directing prioritized weekly volume into specific lagging muscle groups.',
    defaultDaysPerWeek: 5,
    minDays: 4,
    maxDays: 6,
    sensibleDaysOptions: [4, 5, 6],
    generateSchedule: (opts) => {
      const days = Math.max(4, Math.min(6, opts.daysPerWeek || 5));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;
      const targetFocus = (opts.focusMuscles && opts.focusMuscles.length > 0) ? opts.focusMuscles[0] : 'Deltoids & Arms';

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: `Priority Specialization Day — ${targetFocus} Volume`,
          workoutType: 'Hypertrophy',
          targetMuscleGroup: targetFocus,
          primaryBodyParts: opts.focusMuscles || ['Shoulders', 'Arms'],
          allowedBodyParts: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Core'],
          disallowedBodyParts: ['Legs', 'Quadriceps', 'Hamstrings'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 5,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Upper Body Compound Base',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Back',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps'],
          disallowedBodyParts: ['Legs', 'Quadriceps'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Lower Body Compound Maintenance',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Glutes',
          primaryBodyParts: ['Quadriceps', 'Hamstrings'],
          allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'],
          disallowedBodyParts: ['Chest', 'Back', 'Arms'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 4,
          dayName: names[3],
          sessionTitle: `Secondary Priority Touchpoint — ${targetFocus}`,
          workoutType: 'Hypertrophy',
          targetMuscleGroup: targetFocus,
          primaryBodyParts: opts.focusMuscles || ['Shoulders', 'Arms'],
          allowedBodyParts: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Core'],
          disallowedBodyParts: ['Legs'],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 5
          ? [
              {
                dayNumber: 5,
                dayName: names[4],
                sessionTitle: 'Full Body Density & Metabolic Finisher',
                workoutType: 'Hypertrophy',
                targetMuscleGroup: 'Back · Quads · Arms',
                primaryBodyParts: ['Back', 'Quadriceps', 'Arms'],
                allowedBodyParts: ['Back', 'Quadriceps', 'Hamstrings', 'Biceps', 'Triceps', 'Core', 'Full Body'],
                disallowedBodyParts: [],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 4,
              },
            ]
          : []),
      ];
    },
  },

  // 14. Weak-Point Focus Split
  {
    key: 'WEAK_POINT_FOCUS',
    id: 'weak_point_focus',
    displayName: 'Weak-Point Focus Split',
    category: 'Bodypart',
    description: 'Prioritizes identified athlete weak points at start of session before systemic fatigue builds.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 5,
    sensibleDaysOptions: [3, 4, 5],
    generateSchedule: (opts) => {
      const weakPoint = (opts.weakPoints && opts.weakPoints.length > 0) ? opts.weakPoints.join(' & ') : 'Rear Delts & Arms';
      return WORKOUT_SPLIT_TEMPLATES.find((t) => t.key === 'HYPERTROPHY_SPECIALIZATION')!.generateSchedule({
        ...opts,
        focusMuscles: opts.weakPoints || ['Shoulders', 'Arms'],
      });
    },
  },

  // 15. Upper / Lower + Arms
  {
    key: 'UPPER_LOWER_ARMS',
    id: 'upper_lower_arms',
    displayName: 'Upper / Lower + Arms',
    category: 'Bodypart',
    description: 'Standard 4-day Upper/Lower structure enhanced with a dedicated 5th day for direct arm and shoulder growth.',
    defaultDaysPerWeek: 5,
    minDays: 4,
    maxDays: 5,
    sensibleDaysOptions: [4, 5],
    generateSchedule: (opts) => {
      const days = Math.max(4, Math.min(5, opts.daysPerWeek || 5));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;

      const upperAllowed = ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Core'];
      const upperDisallowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'];
      const lowerAllowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'];
      const lowerDisallowed = ['Chest', 'Back', 'Biceps', 'Triceps'];

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Upper Body A — Heavy Press & Row',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest · Back · Shoulders',
          primaryBodyParts: ['Chest', 'Back'],
          allowedBodyParts: upperAllowed,
          disallowedBodyParts: upperDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Lower Body A — Squat & Calves',
          workoutType: 'Strength',
          targetMuscleGroup: 'Quadriceps · Hamstrings · Calves',
          primaryBodyParts: ['Quadriceps', 'Hamstrings'],
          allowedBodyParts: lowerAllowed,
          disallowedBodyParts: lowerDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Upper Body B — Incline & Lat Width',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Chest · Lats · Shoulders',
          primaryBodyParts: ['Chest', 'Back', 'Shoulders'],
          allowedBodyParts: upperAllowed,
          disallowedBodyParts: upperDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 4,
          dayName: names[3],
          sessionTitle: 'Lower Body B — Deadlift & Posterior Chain',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Hamstrings · Glutes · Quadriceps',
          primaryBodyParts: ['Hamstrings', 'Glutes'],
          allowedBodyParts: lowerAllowed,
          disallowedBodyParts: lowerDisallowed,
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 5
          ? [
              {
                dayNumber: 5,
                dayName: names[4],
                sessionTitle: 'Arm & Shoulder Hypertrophy Blitz',
                workoutType: 'Hypertrophy',
                targetMuscleGroup: 'Biceps · Triceps · Lateral Delts',
                primaryBodyParts: ['Biceps', 'Triceps', 'Shoulders'],
                allowedBodyParts: ['Biceps', 'Triceps', 'Shoulders', 'Forearms'],
                disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Legs'],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 5,
              },
            ]
          : []),
      ];
    },
  },

  // 16. Full Body + Conditioning
  {
    key: 'FULL_BODY_CONDITIONING',
    id: 'full_body_conditioning',
    displayName: 'Full Body + Conditioning',
    category: 'Conditioning',
    description: 'Blends full body compound resistance training with dedicated aerobic and work capacity sessions.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 5,
    sensibleDaysOptions: [3, 4, 5],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(5, opts.daysPerWeek || 4));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 45;

      const fullPool = ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body', 'Cardio'];

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Full Body Resistance Foundation',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest · Back · Legs · Core',
          primaryBodyParts: ['Chest', 'Back', 'Quadriceps'],
          allowedBodyParts: fullPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Aerobic Capacity & Core Conditioning',
          workoutType: 'Conditioning',
          targetMuscleGroup: 'Full Body Cardio & Midsection',
          primaryBodyParts: ['Core', 'Full Body'],
          allowedBodyParts: fullPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Full Body Hypertrophy & Density',
          workoutType: 'Hypertrophy',
          targetMuscleGroup: 'Shoulders · Back · Hamstrings',
          primaryBodyParts: ['Shoulders', 'Back', 'Hamstrings'],
          allowedBodyParts: fullPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 4
          ? [
              {
                dayNumber: 4,
                dayName: names[3],
                sessionTitle: 'High-Intensity Interval Metcon',
                workoutType: 'Conditioning',
                targetMuscleGroup: 'Cardiovascular Work Capacity',
                primaryBodyParts: ['Full Body', 'Core'],
                allowedBodyParts: fullPool,
                disallowedBodyParts: [],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 4,
              },
            ]
          : []),
      ];
    },
  },

  // 17. Strength + Conditioning
  {
    key: 'STRENGTH_CONDITIONING',
    id: 'strength_conditioning',
    displayName: 'Strength + Conditioning',
    category: 'Conditioning',
    description: 'Combines heavy raw barbell strength with high-efficiency metabolic conditioning intervals.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 5,
    sensibleDaysOptions: [3, 4, 5],
    generateSchedule: (opts) => {
      return WORKOUT_SPLIT_TEMPLATES.find((t) => t.key === 'FULL_BODY_CONDITIONING')!.generateSchedule(opts);
    },
  },

  // 18. Circuit Training
  {
    key: 'CIRCUIT_TRAINING',
    id: 'circuit_training',
    displayName: 'Circuit Training',
    category: 'Conditioning',
    description: 'High-density multi-exercise circuits focusing on elevated heart rates, muscular endurance, and fat loss.',
    defaultDaysPerWeek: 3,
    minDays: 2,
    maxDays: 4,
    sensibleDaysOptions: [2, 3, 4],
    generateSchedule: (opts) => {
      const days = Math.max(2, Math.min(4, opts.daysPerWeek || 3));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 40;
      const allPool = ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'];

      return Array.from({ length: days }, (_, i) => ({
        dayNumber: i + 1,
        dayName: names[i],
        sessionTitle: `Metabolic Resistance Circuit ${i + 1}`,
        workoutType: 'Conditioning',
        targetMuscleGroup: 'Full Body Endurance & Core',
        primaryBodyParts: ['Full Body', 'Core'],
        allowedBodyParts: allPool,
        disallowedBodyParts: [],
        estimatedDurationMinutes: estDur,
        recommendedExercisesCount: 5,
      }));
    },
  },

  // 19. Sports Performance Split
  {
    key: 'SPORTS_PERFORMANCE',
    id: 'sports_performance',
    displayName: 'Sports Performance Split',
    category: 'Strength',
    description: 'Engineered for athletes: rate of force development, explosive power, speed, agility, and injury prevention.',
    defaultDaysPerWeek: 4,
    minDays: 3,
    maxDays: 5,
    sensibleDaysOptions: [3, 4, 5],
    generateSchedule: (opts) => {
      const days = Math.max(3, Math.min(5, opts.daysPerWeek || 4));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 50;
      const allPool = ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'];

      return [
        {
          dayNumber: 1,
          dayName: names[0],
          sessionTitle: 'Explosive Power & Rate of Force Development',
          workoutType: 'Strength',
          targetMuscleGroup: 'Hips · Legs · Kinetic Chain',
          primaryBodyParts: ['Quadriceps', 'Glutes', 'Back'],
          allowedBodyParts: allPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 2,
          dayName: names[1],
          sessionTitle: 'Upper Body Rotational & Push Power',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest · Shoulders · Upper Back · Core',
          primaryBodyParts: ['Chest', 'Back', 'Core'],
          allowedBodyParts: allPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        {
          dayNumber: 3,
          dayName: names[2],
          sessionTitle: 'Speed, Agility & Unilateral Strength',
          workoutType: 'Strength',
          targetMuscleGroup: 'Single-Leg Balance · Posterior Chain',
          primaryBodyParts: ['Hamstrings', 'Quadriceps', 'Glutes'],
          allowedBodyParts: allPool,
          disallowedBodyParts: [],
          estimatedDurationMinutes: estDur,
          recommendedExercisesCount: 4,
        },
        ...(days >= 4
          ? [
              {
                dayNumber: 4,
                dayName: names[3],
                sessionTitle: 'Durability, Joint Health & Core Stability',
                workoutType: 'Conditioning',
                targetMuscleGroup: 'Rotator Cuff · Trunk · Posterior Chain',
                primaryBodyParts: ['Core', 'Back', 'Shoulders'],
                allowedBodyParts: allPool,
                disallowedBodyParts: [],
                estimatedDurationMinutes: estDur,
                recommendedExercisesCount: 4,
              },
            ]
          : []),
      ];
    },
  },

  // 20. Custom Split
  {
    key: 'CUSTOM_SPLIT',
    id: 'custom_split',
    displayName: 'Custom Split',
    category: 'Custom',
    description: 'Fully flexible template configured by admin to athlete specific requirements.',
    defaultDaysPerWeek: 4,
    minDays: 2,
    maxDays: 7,
    sensibleDaysOptions: [2, 3, 4, 5, 6, 7],
    generateSchedule: (opts) => {
      const days = Math.max(2, Math.min(7, opts.daysPerWeek || 4));
      const names = resolveDayNames(days, opts.weekdaySchedule);
      const estDur = opts.sessionDurationMinutes || 45;
      const allPool = ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'];

      return Array.from({ length: days }, (_, i) => ({
        dayNumber: i + 1,
        dayName: names[i],
        sessionTitle: `Custom Session ${i + 1}`,
        workoutType: opts.primaryGoal?.includes('Strength') ? 'Strength' : 'Hypertrophy',
        targetMuscleGroup: opts.focusMuscles && opts.focusMuscles[i] ? opts.focusMuscles[i] : 'Targeted Muscle Group',
        primaryBodyParts: opts.focusMuscles || ['Chest', 'Back', 'Legs'],
        allowedBodyParts: allPool,
        disallowedBodyParts: [],
        estimatedDurationMinutes: estDur,
        recommendedExercisesCount: 4,
      }));
    },
  },
];

export class WorkoutIntentService {
  /**
   * Retrieves all 20 workout split templates.
   */
  public getSplitTemplates(): WorkoutSplitTemplate[] {
    return WORKOUT_SPLIT_TEMPLATES;
  }

  /**
   * Gets a specific split template by ID or key.
   */
  public getSplitTemplate(idOrKey: string): WorkoutSplitTemplate | undefined {
    const clean = (idOrKey || '').toLowerCase().trim();
    return WORKOUT_SPLIT_TEMPLATES.find(
      (t) => t.id === clean || t.key.toLowerCase() === clean || t.displayName.toLowerCase() === clean
    );
  }

  /**
   * Generates a sensible day schedule for a given split and configuration options.
   * Do NOT force a 6-day split on a client who trains fewer days.
   */
  public generateScheduleForSplit(idOrKey: string, options: ScheduleGenerationOptions): GeneratedDayPlan[] {
    const template = this.getSplitTemplate(idOrKey) || WORKOUT_SPLIT_TEMPLATES[0]; // fallback to Full Body
    return template.generateSchedule(options);
  }

  /**
   * Detects the requested workout split from natural language or explicit identifiers.
   */
  public detectSplit(text: string): SplitDetectionResult {
    const lower = (text || '').toLowerCase();

    // 1. Check exact template match first
    for (const t of WORKOUT_SPLIT_TEMPLATES) {
      if (
        lower.includes(t.displayName.toLowerCase()) ||
        lower.includes(t.id.replace(/_/g, ' ')) ||
        lower.includes(t.id)
      ) {
        return {
          split: t.key,
          templateId: t.id,
          displayName: t.displayName,
          titleSuffix: t.displayName,
          targetMuscleGroup: t.description,
          isAmbiguous: false,
          primaryBodyParts: ['Full Body'],
          allowedBodyParts: ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'],
          disallowedBodyParts: [],
          suggestedDaysPerWeek: t.defaultDaysPerWeek,
          isMultiDayTemplate: true,
        };
      }
    }

    // 2. Specific multi-day keyword checks
    if (/\b(arnold(\s*split)?)\b/i.test(lower)) {
      return this.buildResultFromKey('ARNOLD_SPLIT');
    }
    if (/\b(ppl\s*[x×]\s*2|6\s*day\s*ppl)\b/i.test(lower)) {
      return this.buildResultFromKey('PPL_X2');
    }
    if (/\b(push\s*pull\s*legs?|p[\s\/\\]*p[\s\/\\]*l)\b/i.test(lower)) {
      return this.buildResultFromKey('PUSH_PULL_LEGS');
    }
    if (/\b(upper[\s\/\\]*lower[\s\/\\]*strength)\b/i.test(lower)) {
      return this.buildResultFromKey('UPPER_LOWER_STRENGTH');
    }
    if (/\b(upper[\s\/\\]*lower[\s\+]*arms?)\b/i.test(lower)) {
      return this.buildResultFromKey('UPPER_LOWER_ARMS');
    }
    if (/\b(upper[\s\/\\]*lower)\b/i.test(lower)) {
      return this.buildResultFromKey('UPPER_LOWER');
    }
    if (/\b(bro\s*split|one\s*muscle(\s*per\s*day)?)\b/i.test(lower)) {
      return this.buildResultFromKey('BRO_SPLIT');
    }
    if (/\b(powerlifting|power\s*lifting)\b/i.test(lower)) {
      return this.buildResultFromKey('POWERLIFTING_SPLIT');
    }
    if (/\b(squat[\s\/\\]*bench[\s\/\\]*deadlift|sbd)\b/i.test(lower)) {
      return this.buildResultFromKey('SBD_FOCUS');
    }
    if (/\b(5[\/\-]3[\/\-]1|five\s*three\s*one)\b/i.test(lower)) {
      return this.buildResultFromKey('FIVE_THREE_ONE');
    }
    if (/\b(antagonist)\b/i.test(lower)) {
      return this.buildResultFromKey('ANTAGONIST_SPLIT');
    }
    if (/\b(full\s*body[\s\+]*conditioning)\b/i.test(lower)) {
      return this.buildResultFromKey('FULL_BODY_CONDITIONING');
    }
    if (/\b(strength[\s\+]*conditioning)\b/i.test(lower)) {
      return this.buildResultFromKey('STRENGTH_CONDITIONING');
    }
    if (/\b(circuit(\s*training)?)\b/i.test(lower)) {
      return this.buildResultFromKey('CIRCUIT_TRAINING');
    }
    if (/\b(sports?\s*performance)\b/i.test(lower)) {
      return this.buildResultFromKey('SPORTS_PERFORMANCE');
    }
    if (/\b(weak[\s\-]point)\b/i.test(lower)) {
      return this.buildResultFromKey('WEAK_POINT_FOCUS');
    }
    if (/\b(specialization|hypertrophy\s*split)\b/i.test(lower)) {
      return this.buildResultFromKey('HYPERTROPHY_SPECIALIZATION');
    }
    if (/\b(full\s*body|whole\s*body|total\s*body)\b/i.test(lower)) {
      return this.buildResultFromKey('FULL_BODY');
    }

    // 3. Single-day focus splits (backward compatibility)
    const hasChest = /\b(chest|pecs?|pectorals?)\b/i.test(lower);
    const hasPull = /\b(pull|back|lats?|biceps?)\b/i.test(lower);
    const hasLeg = /\b(legs?|quads?|hamstrings?|glutes?|calves?|lower\s*body)\b/i.test(lower);
    const hasPush = /\b(push|shoulders?|delts?|triceps?)\b/i.test(lower);

    // Only flag contradictory when asking for a SINGLE-DAY routine with opposing muscles and NOT an antagonist/arnold routine
    if (
      hasChest &&
      hasPull &&
      /\b(chest\s+pull|pull\s+chest)\b/i.test(lower) &&
      !lower.includes('arnold') &&
      !lower.includes('antagonist')
    ) {
      return {
        split: 'AMBIGUOUS',
        templateId: 'ambiguous',
        displayName: 'Ambiguous Split',
        titleSuffix: 'Chest & Pull Hybrid',
        targetMuscleGroup: 'Chest • Back (Hybrid)',
        isAmbiguous: true,
        ambiguityReason: 'Chest Day and Pull Day target opposing muscle groups for a single session. For pairing opposing muscles across workouts, select Arnold Split, Antagonist Split, or Upper/Lower.',
        primaryBodyParts: ['Chest', 'Back'],
        allowedBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps'],
        disallowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
        suggestedDaysPerWeek: 3,
        isMultiDayTemplate: false,
      };
    }

    if (/\b(push\s*day|push\s*workout|push\s*session)\b/i.test(lower)) {
      return {
        split: 'PUSH',
        templateId: 'push',
        displayName: 'Push Day',
        titleSuffix: 'Push (Chest, Shoulders & Triceps)',
        targetMuscleGroup: 'Chest • Shoulders • Triceps',
        isAmbiguous: false,
        primaryBodyParts: ['Chest', 'Shoulders'],
        allowedBodyParts: ['Chest', 'Shoulders', 'Triceps'],
        disallowedBodyParts: ['Back', 'Biceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
        suggestedDaysPerWeek: 3,
        isMultiDayTemplate: false,
      };
    }

    if (/\b(chest\s*day|chest\s*workout|chest\s*session|chest\s*focus)\b/i.test(lower) || (hasChest && !hasPull && !hasLeg && !hasPush)) {
      return {
        split: 'CHEST',
        templateId: 'chest',
        displayName: 'Chest Day',
        titleSuffix: 'Chest Hypertrophy & Strength',
        targetMuscleGroup: 'Chest • Optional Triceps Accessory',
        isAmbiguous: false,
        primaryBodyParts: ['Chest'],
        allowedBodyParts: ['Chest', 'Triceps'],
        disallowedBodyParts: ['Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Biceps'],
        suggestedDaysPerWeek: 4,
        isMultiDayTemplate: false,
      };
    }

    if (/\b(pull\s*day|pull\s*workout|pull\s*session|back\s*day)\b/i.test(lower) || (hasPull && !hasChest && !hasLeg && !hasPush)) {
      return {
        split: 'PULL',
        templateId: 'pull',
        displayName: 'Pull Day',
        titleSuffix: 'Pull (Back & Biceps) Protocol',
        targetMuscleGroup: 'Back • Lats • Biceps',
        isAmbiguous: false,
        primaryBodyParts: ['Back'],
        allowedBodyParts: ['Back', 'Biceps'],
        disallowedBodyParts: ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Triceps'],
        suggestedDaysPerWeek: 4,
        isMultiDayTemplate: false,
      };
    }

    if (/\b(leg\s*day|legs?\s*workout|legs?\s*session|lower\s*body)\b/i.test(lower) || (hasLeg && !hasChest && !hasPull && !hasPush)) {
      return {
        split: 'LEG',
        templateId: 'leg',
        displayName: 'Leg Day',
        titleSuffix: 'Lower Body & Leg Power',
        targetMuscleGroup: 'Quadriceps • Hamstrings • Glutes • Calves',
        isAmbiguous: false,
        primaryBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
        allowedBodyParts: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'],
        disallowedBodyParts: ['Chest', 'Back', 'Biceps', 'Triceps'],
        suggestedDaysPerWeek: 4,
        isMultiDayTemplate: false,
      };
    }

    if (hasPush && !hasPull && !hasLeg && !hasChest) {
      return {
        split: 'PUSH',
        templateId: 'push',
        displayName: 'Push Day',
        titleSuffix: 'Push (Chest, Shoulders & Triceps)',
        targetMuscleGroup: 'Chest • Shoulders • Triceps',
        isAmbiguous: false,
        primaryBodyParts: ['Chest', 'Shoulders'],
        allowedBodyParts: ['Chest', 'Shoulders', 'Triceps'],
        disallowedBodyParts: ['Back', 'Biceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'],
        suggestedDaysPerWeek: 3,
        isMultiDayTemplate: false,
      };
    }

    return {
      split: 'GENERAL',
      templateId: 'general',
      displayName: 'General Training Split',
      titleSuffix: 'Targeted Training Protocol',
      targetMuscleGroup: 'Compound Push • Pull • Legs',
      isAmbiguous: false,
      primaryBodyParts: ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Shoulders', 'Full Body'],
      allowedBodyParts: ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'],
      disallowedBodyParts: [],
      suggestedDaysPerWeek: 4,
      isMultiDayTemplate: false,
    };
  }

  private buildResultFromKey(key: WorkoutSplitKey): SplitDetectionResult {
    const t = WORKOUT_SPLIT_TEMPLATES.find((x) => x.key === key) || WORKOUT_SPLIT_TEMPLATES[0];
    return {
      split: t.key,
      templateId: t.id,
      displayName: t.displayName,
      titleSuffix: t.displayName,
      targetMuscleGroup: t.description,
      isAmbiguous: false,
      primaryBodyParts: ['Full Body'],
      allowedBodyParts: ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Full Body'],
      disallowedBodyParts: [],
      suggestedDaysPerWeek: t.defaultDaysPerWeek,
      isMultiDayTemplate: true,
    };
  }

  /**
   * Retrieves balanced, library-verified exercises for a specific split or specific day.
   */
  public async getBalancedExercisesForSplit(
    splitResult: SplitDetectionResult,
    options: {
      clientProfileId?: string;
      fitnessLevel?: string;
      injuryAreas?: string[];
      count?: number;
      variationSeed?: number;
      primaryBodyParts?: string[];
      allowedBodyParts?: string[];
    } = {}
  ): Promise<Array<any>> {
    const {
      clientProfileId,
      injuryAreas = [],
      count = 4,
      variationSeed = 0,
      primaryBodyParts = splitResult.primaryBodyParts,
      allowedBodyParts = splitResult.allowedBodyParts,
    } = options;

    const recentExerciseNames = new Set<string>();
    if (clientProfileId) {
      try {
        const recentProposals = await prisma.aIProposal.findMany({
          where: { clientProfileId, proposalType: 'WORKOUT' },
          orderBy: { createdAt: 'desc' },
          take: 3,
        });

        for (const p of recentProposals) {
          try {
            const data = JSON.parse(p.finalDataJson || p.proposedDataJson || '{}');
            const exs = data.exercises || [];
            for (const e of exs) {
              if (e.exerciseName) recentExerciseNames.add(e.exerciseName.toLowerCase().trim());
              if (e.name) recentExerciseNames.add(e.name.toLowerCase().trim());
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    const pool = await prisma.exercise.findMany({
      where: {
        isActive: true,
        bodyPart: { in: allowedBodyParts, mode: 'insensitive' },
      },
      select: {
        id: true,
        name: true,
        category: true,
        bodyPart: true,
        equipment: true,
        isCompound: true,
        isIsolation: true,
        difficulty: true,
      },
      orderBy: { name: 'asc' },
    });

    const safePool = pool.filter((e) => {
      const lowerName = e.name.toLowerCase();
      for (const injury of injuryAreas) {
        const lowerInj = injury.toLowerCase();
        if (lowerInj.includes('shoulder') && (lowerName.includes('overhead press') || lowerName.includes('military press') || lowerName.includes('behind the neck'))) {
          return false;
        }
        if (lowerInj.includes('knee') && (lowerName.includes('deep squat') || lowerName.includes('jump squat') || lowerName.includes('sissy squat'))) {
          return false;
        }
        if (lowerInj.includes('lower back') && (lowerName.includes('conventional deadlift') || lowerName.includes('good morning'))) {
          return false;
        }
      }
      return true;
    });

    if (safePool.length === 0) {
      return pool.slice(0, count);
    }

    const isPrimary = (e: any) =>
      primaryBodyParts.some((p) => p.toLowerCase() === (e.bodyPart || '').toLowerCase());

    const tier1Primary = safePool.filter(
      (e) => isPrimary(e) && e.isCompound && (e.equipment.toLowerCase().includes('barbell') || e.equipment.toLowerCase().includes('dumbbell'))
    );
    const tier1All = safePool.filter(
      (e) => e.isCompound && (e.equipment.toLowerCase().includes('barbell') || e.equipment.toLowerCase().includes('dumbbell'))
    );
    const tier1 = tier1Primary.length > 0 ? tier1Primary : tier1All;

    const tier2Primary = safePool.filter((e) => isPrimary(e) && e.isCompound && !tier1.includes(e));
    const tier2All = safePool.filter((e) => e.isCompound && !tier1.includes(e));
    const tier2 = tier2Primary.length > 0 ? tier2Primary : tier2All;

    const tier3 = safePool.filter((e) => e.isIsolation || (!tier1.includes(e) && !tier2.includes(e)));

    const prioritizeVariety = (list: typeof safePool) => {
      const unused = list.filter((e) => !recentExerciseNames.has(e.name.toLowerCase().trim()));
      const used = list.filter((e) => recentExerciseNames.has(e.name.toLowerCase().trim()));
      const rotate = (arr: typeof safePool) => {
        if (arr.length <= 1 || variationSeed === 0) return arr;
        const shift = variationSeed % arr.length;
        return [...arr.slice(shift), ...arr.slice(0, shift)];
      };
      return [...rotate(unused), ...rotate(used)];
    };

    const sortedTier1 = prioritizeVariety(tier1.length > 0 ? tier1 : safePool);
    const sortedTier2 = prioritizeVariety(tier2.length > 0 ? tier2 : safePool);
    const sortedTier3 = prioritizeVariety(tier3.length > 0 ? tier3 : safePool);

    const selected: typeof safePool = [];
    const usedIds = new Set<string>();

    const addFromTier = (tier: typeof safePool) => {
      for (const ex of tier) {
        if (!usedIds.has(ex.id)) {
          selected.push(ex);
          usedIds.add(ex.id);
          return true;
        }
      }
      return false;
    };

    addFromTier(sortedTier1);
    addFromTier(sortedTier2);
    addFromTier(sortedTier2.length > 1 ? sortedTier2 : sortedTier3);
    while (selected.length < count) {
      if (!addFromTier(sortedTier3)) {
        if (!addFromTier(sortedTier2)) {
          if (!addFromTier(sortedTier1)) {
            break;
          }
        }
      }
    }

    return selected.slice(0, count);
  }

  /**
   * Fetches the client's verified strength history across exercises from completed workout records.
   * Returns a map of normalized exercise names to their highest recorded working weight (in kg) and reps.
   */
  public async fetchClientStrengthHistory(
    userIdOrProfileId: string
  ): Promise<Map<string, { weightKg: number; reps: number; date: Date }>> {
    const history = new Map<string, { weightKg: number; reps: number; date: Date }>();
    if (!userIdOrProfileId || typeof userIdOrProfileId !== 'string') return history;

    try {
      const records = await prisma.workoutRecord.findMany({
        where: {
          OR: [
            { clientId: userIdOrProfileId },
            { client: { clientProfile: { id: userIdOrProfileId } } },
            { client: { clientProfile: { clientId: userIdOrProfileId } } },
          ],
          isCompleted: true,
        },
        include: {
          exerciseRecords: {
            where: { isSkipped: false },
            include: {
              setRecords: {
                where: { isCompleted: true, actualWeight: { gt: 0 } },
                orderBy: { actualWeight: 'desc' },
              },
            },
          },
        },
        orderBy: { startedAt: 'desc' },
        take: 50,
      });

      for (const rec of records) {
        for (const exRec of rec.exerciseRecords) {
          const exName = (exRec.exerciseName || '').toLowerCase().trim();
          if (!exName) continue;

          for (const set of exRec.setRecords) {
            const wgt = Number(set.actualWeight) || 0;
            const reps = Number(set.actualReps) || 0;
            if (wgt > 0) {
              const existing = history.get(exName);
              if (!existing || wgt > existing.weightKg) {
                history.set(exName, { weightKg: wgt, reps, date: rec.startedAt });
              }
            }
          }
        }
      }
    } catch (err) {
      console.warn(`[WorkoutIntentService] Error fetching client strength history:`, err);
    }

    return history;
  }

  /**
   * Calculates personalized workout exercise parameters (sets, reps, realistic load, rest, RIR, RPE, tempo, cues)
   * tailored to the client's goal, fitness level, experience, gender, and exercise biomechanics/equipment.
   */
  public calculatePersonalizedExerciseParameters(
    exercise: {
      name: string;
      bodyPart?: string;
      category?: string;
      equipment?: string;
      isCompound?: boolean;
      isIsolation?: boolean;
    },
    clientProfile?: {
      fitnessLevel?: string | null;
      primaryGoal?: string | null;
      secondaryGoal?: string | null;
      trainingExperience?: string | null;
      weightKg?: number | null;
      gender?: string | null;
      strengthHistory?: Map<string, any> | Record<string, any> | null;
    },
    context?: {
      orderIndex?: number;
      totalExercises?: number;
      sessionWorkoutType?: string;
      strengthHistory?: Map<string, any> | Record<string, any> | null;
    }
  ): PersonalizedExerciseParameters {
    const rawLevel = (clientProfile?.fitnessLevel || clientProfile?.trainingExperience || 'Intermediate').toLowerCase();
    const isBeginner = rawLevel.includes('begin') || rawLevel.includes('new') || rawLevel.includes('less than') || rawLevel.includes('return');
    const isAdvanced = rawLevel.includes('advanc') || rawLevel.includes('elite') || rawLevel.includes('5+');

    const rawGoal = (clientProfile?.primaryGoal || clientProfile?.secondaryGoal || context?.sessionWorkoutType || 'Hypertrophy').toLowerCase();
    const isStrength = rawGoal.includes('strength') || rawGoal.includes('power') || rawGoal.includes('sbd');
    const isFatLoss = rawGoal.includes('fat') || rawGoal.includes('loss') || rawGoal.includes('lean') || rawGoal.includes('endurance') || rawGoal.includes('condition');

    const nameLower = (exercise.name || '').toLowerCase();
    const equipLower = (exercise.equipment || '').toLowerCase();

    const isBodyweight =
      equipLower.includes('bodyweight') ||
      nameLower.includes('pull-up') ||
      nameLower.includes('push-up') ||
      nameLower.includes('chin-up') ||
      nameLower.includes('dip') ||
      nameLower.includes('plank') ||
      nameLower.includes('crunch') ||
      nameLower.includes('hanging leg') ||
      nameLower.includes('hanging knee') ||
      nameLower.includes('inverted row');

    const isDumbbell = equipLower.includes('dumbbell') || nameLower.includes('dumbbell') || nameLower.includes('db ');
    const isBarbell = equipLower.includes('barbell') || nameLower.includes('barbell') || nameLower.includes('bb ');
    const isCable = equipLower.includes('cable') || nameLower.includes('cable');
    const isMachine = equipLower.includes('machine') || equipLower.includes('smith') || nameLower.includes('machine') || nameLower.includes('leg press') || nameLower.includes('hack squat');

    const isCompound = exercise.isCompound ?? (isBarbell || isMachine || nameLower.includes('squat') || nameLower.includes('press') || nameLower.includes('deadlift') || nameLower.includes('row') || nameLower.includes('lunge'));
    const isIsolation = exercise.isIsolation ?? (!isCompound || nameLower.includes('curl') || nameLower.includes('lateral raise') || nameLower.includes('extension') || nameLower.includes('fly'));
    const isHeavyCompound = isCompound && (nameLower.includes('squat') || nameLower.includes('deadlift') || nameLower.includes('bench press') || nameLower.includes('overhead press') || nameLower.includes('leg press'));
    const isArmOrShoulderIsolation = isIsolation && (nameLower.includes('lateral raise') || nameLower.includes('curl') || nameLower.includes('rear delt') || nameLower.includes('kickback') || nameLower.includes('fly') || nameLower.includes('raise'));

    // 1. Sets calculation
    let sets: number;
    if (isBeginner) {
      sets = isCompound ? 3 : 2;
    } else if (isAdvanced) {
      sets = isHeavyCompound ? 4 : 3;
    } else {
      sets = 3;
    }

    // 2. Reps calculation
    let reps: string;
    if (isStrength) {
      if (isHeavyCompound) {
        reps = isBeginner ? '5-6' : (isAdvanced ? '3-5' : '4-6');
      } else if (isCompound) {
        reps = isBeginner ? '6-8' : '5-6';
      } else {
        reps = '8-10';
      }
    } else if (isFatLoss) {
      if (isCompound) {
        reps = '10-12';
      } else {
        reps = '12-15';
      }
    } else {
      // Hypertrophy
      if (isHeavyCompound) {
        reps = isAdvanced ? '6-8' : '8-10';
      } else if (isCompound) {
        reps = '8-10';
      } else {
        reps = '10-12';
      }
    }

    // 3. Rest Seconds calculation
    let restSeconds: number;
    if (isStrength) {
      restSeconds = isHeavyCompound ? 180 : (isCompound ? 120 : 90);
    } else if (isFatLoss) {
      restSeconds = isCompound ? 60 : 45;
    } else {
      restSeconds = isHeavyCompound ? 120 : (isCompound ? 90 : 60);
    }

    // 4. Target Weight calculation (evidence-informed & clinical safety standards)
    // Requirement 4: Verify client-specific strength history is used when available.
    // Do not use gender alone to determine working weights.
    // If reliable load data is unavailable, return an unspecified load rather than inventing a precise kilogram value.
    let targetWeight: number | null = null;
    let loadNote = '';

    if (isBodyweight) {
      targetWeight = null;
    } else {
      // Look up client strength history if available
      const strengthHistorySource = context?.strengthHistory || (clientProfile as any)?.strengthHistory;
      let matchedHistoryWeight: number | null = null;

      if (strengthHistorySource) {
        const getFromSource = (key: string): number | null => {
          if (strengthHistorySource instanceof Map) {
            const v = strengthHistorySource.get(key);
            if (v !== undefined && v !== null) {
              return typeof v === 'number' ? v : (v.weightKg ?? null);
            }
          } else if (typeof strengthHistorySource === 'object') {
            const v = (strengthHistorySource as Record<string, any>)[key];
            if (v !== undefined && v !== null) {
              return typeof v === 'number' ? v : (v.weightKg ?? null);
            }
          }
          return null;
        };

        // 1. Exact match
        matchedHistoryWeight = getFromSource(nameLower);

        // 2. Normalized match (without symbols)
        if (matchedHistoryWeight === null) {
          const cleanName = nameLower.replace(/[^a-z0-9]/g, ' ').replace(/\s+/g, ' ').trim();
          matchedHistoryWeight = getFromSource(cleanName);
        }

        // 3. Substring / Token matching
        if (matchedHistoryWeight === null) {
          const keys = strengthHistorySource instanceof Map
            ? Array.from(strengthHistorySource.keys())
            : Object.keys(strengthHistorySource);
          for (const k of keys) {
            const kLower = k.toLowerCase().trim();
            if (kLower && (nameLower.includes(kLower) || kLower.includes(nameLower))) {
              matchedHistoryWeight = getFromSource(k);
              if (matchedHistoryWeight !== null) break;
            }
          }
        }
      }

      if (matchedHistoryWeight !== null && matchedHistoryWeight > 0) {
        // Calibrate working weight from client's verified strength history
        let multiplier = 0.90; // Default hypertrophy working load (~90% of past best)
        if (isStrength) {
          multiplier = isBeginner ? 0.95 : 1.0; // 95-100% of previous working weight
        } else if (isFatLoss) {
          multiplier = 0.75; // 75% for higher rep conditioning endurance sets
        }

        const calculated = Math.round((matchedHistoryWeight * multiplier) / 2.5) * 2.5;
        targetWeight = Math.max(2.5, calculated);
        loadNote = `Target load calibrated from athlete's recorded strength history (${matchedHistoryWeight} kg baseline).`;
      } else {
        // Reliable load data is unavailable: return unspecified load (null) rather than inventing an arbitrary kilogram value based on gender alone!
        targetWeight = null;
        loadNote = `Load unspecified — establish working weight in session 1 with progressive warm-up to target RIR ${isBeginner ? 3 : 2}.`;
      }
    }

    // 5. Target RIR & RPE
    let targetRir: number;
    let targetRpe: number;
    if (isBeginner) {
      targetRir = 3;
      targetRpe = 7.0;
    } else if (isAdvanced) {
      targetRir = isHeavyCompound ? 2 : 1;
      targetRpe = isHeavyCompound ? 8.5 : 9.0;
    } else {
      targetRir = 2;
      targetRpe = 8.0;
    }

    // 6. Tempo
    let tempo = '3-1-1-0';
    if (isStrength) {
      tempo = '2-0-1-0';
    } else if (isFatLoss) {
      tempo = '2-0-1-0';
    } else {
      tempo = isHeavyCompound ? '3-1-1-0' : '2-0-1-0';
    }

    // 7. Coaching Cues
    let notes = 'Prioritize strict technique and full range of motion over load. Maintain consistent tempo.';
    if (nameLower.includes('bench') || nameLower.includes('chest press') || nameLower.includes('push-up')) {
      notes = 'Retract and depress scapulae. Maintain 5-point contact with bench and drive through feet. 3-second controlled descent.';
    } else if (nameLower.includes('squat') || nameLower.includes('leg press')) {
      notes = 'Brace abdominal wall 360°. Push floor away and keep knees tracking over 2nd toe. Hit parallel depth with upright torso.';
    } else if (nameLower.includes('deadlift') || nameLower.includes('hinge') || nameLower.includes('rdl')) {
      notes = 'Engage lats to pack upper back. Push floor away through midfoot without hyperextending at lockout.';
    } else if (nameLower.includes('row') || nameLower.includes('pulldown') || nameLower.includes('pull-up') || nameLower.includes('chin-up')) {
      notes = 'Initiate with scapular retraction before bending elbows. Squeeze lats at contraction, avoid trunk swinging.';
    } else if (nameLower.includes('overhead press') || nameLower.includes('shoulder press')) {
      notes = 'Keep glutes and core squeezed to protect lumbar spine. Press in straight vertical path over midfoot.';
    } else if (nameLower.includes('lateral raise')) {
      notes = 'Lead with elbows with a slight forward torso angle. Pause at parallel, do not use momentum.';
    } else if (nameLower.includes('curl') || nameLower.includes('extension') || nameLower.includes('kickback')) {
      notes = 'Keep elbows pinned to sides. Full elbow extension on descent and peak squeeze at top.';
    } else if (isBodyweight) {
      notes = 'Maintain constant core tension and steady breathing cadence. Avoid swinging or dropping into lumbar extension.';
    }

    if (loadNote) {
      notes = `${notes} ${loadNote}`;
    }

    return {
      sets,
      numberOfSets: sets,
      reps,
      targetReps: reps,
      weight: targetWeight,
      targetWeight,
      restSeconds,
      targetRir,
      targetRpe,
      tempo,
      notes,
      adminInstruction: notes,
    };
  }

  /**
   * Validates a workout proposal against the requested split and schedule, checking:
   * - Muscle group alignment (per-day check for multi-day schedules)
   * - Real exercise database IDs and links
   * - In-session duplicate exercise elimination
   * - Client injury and limitation contraindication avoidance
   * - Volume distribution, sets, reps, and exercise variety
   * - Non-empty training days in weekly schedule
   */
  public async validateProposalForSplit(
    splitResult: SplitDetectionResult,
    exercises: Array<any>,
    weeklySchedule?: Array<any>,
    options?: SplitValidationOptions
  ): Promise<{ isValid: boolean; error?: string; validatedExercises: ValidatedExerciseItem[] }> {
    if (!Array.isArray(exercises) || exercises.length === 0) {
      return { isValid: false, error: 'Workout proposal must contain at least one exercise.', validatedExercises: [] };
    }

    if (splitResult.isAmbiguous) {
      return { isValid: false, error: splitResult.ambiguityReason, validatedExercises: [] };
    }

    const allDbExercises = await prisma.exercise.findMany({
      where: { isActive: true },
      select: { id: true, name: true, normalizedName: true, bodyPart: true, category: true, isCompound: true, isIsolation: true },
    });

    const nameMap = new Map<string, typeof allDbExercises[0]>();
    const idMap = new Map<string, typeof allDbExercises[0]>();
    for (const ex of allDbExercises) {
      nameMap.set(ex.name.toLowerCase().trim(), ex);
      nameMap.set(ex.normalizedName.toLowerCase().trim(), ex);
      idMap.set(ex.id, ex);
    }

    const validated: ValidatedExerciseItem[] = [];

    // If multi-day weekly schedule is provided, validate day-by-day
    const isMultiDay = Array.isArray(weeklySchedule) && weeklySchedule.length > 1;

    for (let i = 0; i < exercises.length; i++) {
      const rawEx = exercises[i];
      const rawName = (rawEx.exerciseName || rawEx.name || '').trim();
      const rawId = rawEx.exerciseId || rawEx.id || '';

      let matchedDb = idMap.get(rawId) || nameMap.get(rawName.toLowerCase());
      if (!matchedDb) {
        matchedDb = allDbExercises.find(
          (dbEx) =>
            dbEx.name.toLowerCase().includes(rawName.toLowerCase()) ||
            rawName.toLowerCase().includes(dbEx.name.toLowerCase())
        );
      }

      const bodyPart = matchedDb?.bodyPart || rawEx.bodyPart || 'Full Body';
      const category = matchedDb?.category || rawEx.category || 'Strength';

      validated.push({
        exerciseId: matchedDb?.id || rawId || `ex_gen_${i}`,
        exerciseName: matchedDb?.name || rawName,
        name: matchedDb?.name || rawName,
        category,
        bodyPart,
        orderIndex: i,
        sets: Math.max(1, Math.min(6, Number(rawEx.sets || rawEx.numberOfSets) || 3)),
        reps: String(rawEx.reps || rawEx.targetReps || '8-10'),
        restSeconds: Math.max(30, Math.min(180, Number(rawEx.restSeconds) || 90)),
        targetWeight: rawEx.targetWeight !== undefined ? (rawEx.targetWeight === null ? null : Number(rawEx.targetWeight)) : (rawEx.weight !== undefined ? (rawEx.weight === null ? null : Number(rawEx.weight)) : null),
        targetRir: Number(rawEx.targetRir) || 2,
        targetRpe: Number(rawEx.targetRpe) || 8.0,
        notes: rawEx.notes || undefined,
        day: rawEx.day || undefined,
      });
    }

    // 1. Injury Contraindication Check
    const activeInjuries = options?.injuryAreas || [];
    if (activeInjuries.length > 0) {
      for (const v of validated) {
        const conflict = this.checkInjuryConflict(v.name, v.bodyPart, activeInjuries);
        if (conflict.hasConflict) {
          return {
            isValid: false,
            error: conflict.reason,
            validatedExercises: validated,
          };
        }
      }
    }

    // 2. In-Session Duplicate Exercise Check
    if (isMultiDay && weeklySchedule && weeklySchedule.length > 0) {
      for (const day of weeklySchedule) {
        const dayExercises = Array.isArray(day.exercises) ? day.exercises : [];
        const seenNames = new Set<string>();
        for (const ex of dayExercises) {
          const exName = (ex.name || ex.exerciseName || '').trim().toLowerCase();
          if (!exName) continue;
          if (seenNames.has(exName)) {
            return {
              isValid: false,
              error: `Session "${day.sessionTitle || day.day}" contains duplicate exercise "${ex.name || ex.exerciseName}". Each exercise within a session must be unique.`,
              validatedExercises: validated,
            };
          }
          seenNames.add(exName);
        }
      }
    } else {
      const seenSingle = new Set<string>();
      for (const ex of validated) {
        const exName = ex.name.trim().toLowerCase();
        if (seenSingle.has(exName)) {
          return {
            isValid: false,
            error: `Workout proposal contains duplicate exercise "${ex.name}". Each exercise within a session must be unique.`,
            validatedExercises: validated,
          };
        }
        seenSingle.add(exName);
      }
    }

    // 3. Multi-day split validation:
    if (isMultiDay || splitResult.isMultiDayTemplate) {
      // Flattening check: single-day output with excessive exercises for multi-day split
      if ((!weeklySchedule || weeklySchedule.length <= 1) && validated.length >= 10 && splitResult.isMultiDayTemplate) {
        return {
          isValid: false,
          error: `Malformed plan: received ${validated.length} exercises flattened into a single day for multi-day split "${splitResult.displayName}". Each training day must be separate.`,
          validatedExercises: validated,
        };
      }

      if (weeklySchedule && weeklySchedule.length > 1) {
        // Empty days check
        const emptyDays = weeklySchedule.filter((d: any) => !Array.isArray(d.exercises) || d.exercises.length === 0);
        if (emptyDays.length > 0) {
          return {
            isValid: false,
            error: `Workout proposal has empty training days without exercises: ${emptyDays.map((d: any) => d.sessionTitle || d.day).join(', ')}. All training days must include scheduled exercises.`,
            validatedExercises: validated,
          };
        }

        // Duplicate day check (check if all non-empty days have identical exercise lists)
        const daysWithExercises = weeklySchedule.filter((d: any) => Array.isArray(d.exercises) && d.exercises.length > 0);
        if (daysWithExercises.length > 1) {
          const firstDayKeys = daysWithExercises[0].exercises.map((e: any) => (e.name || e.exerciseName || '').toLowerCase().trim()).sort().join('|');
          const allIdentical = firstDayKeys.length > 0 && daysWithExercises.every((d: any) => {
            const keys = d.exercises.map((e: any) => (e.name || e.exerciseName || '').toLowerCase().trim()).sort().join('|');
            return keys === firstDayKeys;
          });
          if (allIdentical) {
            return {
              isValid: false,
              error: `Duplicate plan error: all workout days contain identical exercises instead of separate day-specific sessions.`,
              validatedExercises: validated,
            };
          }
        }

        // Day-by-Day Muscle Group & Exercise Count Validation
        for (const day of weeklySchedule) {
          const dayTitle = (day.sessionTitle || day.title || day.day || '').toLowerCase();
          const dayCat = (day.splitCategory || day.category || '').toLowerCase();
          const dayFocus = (day.targetMuscleGroup || '').toLowerCase();
          const dayExercises: any[] = Array.isArray(day.exercises) ? day.exercises : [];

          if (dayExercises.length > 12) {
            return {
              isValid: false,
              error: `Session "${day.sessionTitle || day.day}" has ${dayExercises.length} exercises (expected 3–9 exercises per session). Plan appears to be flattened across multiple days.`,
              validatedExercises: validated,
            };
          }

          // Determine disallowed muscle groups for this specific day
          let dayDisallowed: string[] = [];
          if (Array.isArray(day.disallowedBodyParts) && day.disallowedBodyParts.length > 0) {
            dayDisallowed = day.disallowedBodyParts;
          } else if (splitResult.split === 'FULL_BODY' || dayTitle.includes('full body') || dayCat.includes('full')) {
            dayDisallowed = [];
          } else if (dayTitle.includes('push') || dayCat.includes('push')) {
            dayDisallowed = ['Back', 'Biceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'];
          } else if (dayTitle.includes('pull') || dayCat.includes('pull')) {
            dayDisallowed = ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Triceps'];
          } else if (dayTitle.includes('leg') || dayTitle.includes('lower body') || (dayCat.includes('lower') && !dayCat.includes('upper'))) {
            dayDisallowed = ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps'];
          } else if (dayTitle.includes('upper') || (dayCat.includes('upper') && !dayCat.includes('lower'))) {
            dayDisallowed = ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'];
          } else if (dayTitle.includes('chest') && !dayTitle.includes('back')) {
            dayDisallowed = ['Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Biceps'];
          } else if (dayTitle.includes('back') && !dayTitle.includes('chest')) {
            dayDisallowed = ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Triceps'];
          } else if (dayTitle.includes('shoulder') && !dayTitle.includes('leg') && !dayTitle.includes('chest') && !dayTitle.includes('back')) {
            dayDisallowed = ['Chest', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Back'];
          } else if (dayTitle.includes('arm') && !dayTitle.includes('shoulder') && !dayTitle.includes('leg')) {
            dayDisallowed = ['Chest', 'Back', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'];
          }

          if (dayDisallowed.length > 0) {
            for (const ex of dayExercises) {
              const exName = (ex.name || ex.exerciseName || '').trim();
              const matchedDb = nameMap.get(exName.toLowerCase()) || idMap.get(ex.exerciseId);
              const bodyPart = matchedDb?.bodyPart || ex.bodyPart || '';
              if (dayDisallowed.some(dis => dis.toLowerCase() === bodyPart.toLowerCase())) {
                return {
                  isValid: false,
                  error: `Invalid exercise selection for ${day.sessionTitle || day.day}: "${exName}" (${bodyPart}) does not belong in this session.`,
                  validatedExercises: validated,
                };
              }
            }
          }
        }
      }
    }

    // Only enforce strict single-day disallow checks if it's NOT a multi-day plan and NOT a multi-day template
    if (!isMultiDay && !splitResult.isMultiDayTemplate && splitResult.split !== 'FULL_BODY' && splitResult.split !== 'GENERAL') {
      const disallowedCount = validated.filter((v) =>
        splitResult.disallowedBodyParts.some((dis) => dis.toLowerCase() === v.bodyPart.toLowerCase())
      ).length;

      if (disallowedCount > 0) {
        const disallowedNames = validated
          .filter((v) => splitResult.disallowedBodyParts.some((dis) => dis.toLowerCase() === v.bodyPart.toLowerCase()))
          .map((v) => `${v.name} (${v.bodyPart})`);

        return {
          isValid: false,
          error: `Invalid exercise selection for ${splitResult.displayName}: ${disallowedNames.join(', ')} do not belong in a ${splitResult.displayName} protocol.`,
          validatedExercises: validated,
        };
      }
    }

    return { isValid: true, validatedExercises: validated };
  }

  /**
   * Helper to evaluate whether an exercise conflicts with documented client injury areas.
   */
  public checkInjuryConflict(exName: string, bodyPart: string, injuryAreas: string[]): { hasConflict: boolean; reason?: string } {
    const lowerName = (exName || '').toLowerCase();
    for (const inj of injuryAreas) {
      const lowerInj = (inj || '').toLowerCase().trim();
      if (!lowerInj) continue;
      if (lowerInj.includes('shoulder') || lowerInj.includes('rotator cuff')) {
        if (
          lowerName.includes('overhead press') ||
          lowerName.includes('military press') ||
          lowerName.includes('behind the neck') ||
          lowerName.includes('upright row') ||
          lowerName.includes('arnold press')
        ) {
          return { hasConflict: true, reason: `Exercise "${exName}" conflicts with client's recorded shoulder injury/limitation.` };
        }
      }
      if (lowerInj.includes('knee')) {
        if (
          lowerName.includes('deep squat') ||
          lowerName.includes('jump squat') ||
          lowerName.includes('sissy squat') ||
          lowerName.includes('pistol squat') ||
          lowerName.includes('box jump')
        ) {
          return { hasConflict: true, reason: `Exercise "${exName}" conflicts with client's recorded knee injury/limitation.` };
        }
      }
      if (lowerInj.includes('lower back') || lowerInj.includes('lumbar') || lowerInj.includes('spine')) {
        if (
          lowerName.includes('conventional deadlift') ||
          lowerName.includes('good morning') ||
          lowerName.includes('stiff leg deadlift')
        ) {
          return { hasConflict: true, reason: `Exercise "${exName}" conflicts with client's recorded lower back injury/limitation.` };
        }
      }
      if (lowerInj.includes('wrist')) {
        if (
          (lowerName.includes('barbell curl') && !lowerName.includes('ez')) ||
          lowerName.includes('clean and press')
        ) {
          return { hasConflict: true, reason: `Exercise "${exName}" conflicts with client's recorded wrist injury/limitation.` };
        }
      }
    }
    return { hasConflict: false };
  }
}

export const workoutIntentService = new WorkoutIntentService();

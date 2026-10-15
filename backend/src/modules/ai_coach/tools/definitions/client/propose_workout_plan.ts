/**
 * Alpha X AI — Tool: propose_workout_plan
 * Phase 7 — AI Plan Proposal Engine
 *
 * The AI calls this tool to save a proposed workout plan for admin review.
 * The plan is NEVER assigned to the client until the admin explicitly approves it.
 */

import { ToolDefinition, ToolPermission, ToolExecutionContext } from '../../tool.types';
import { prisma } from '../../../../../config/prisma';
import { clientDataService } from '../client/client_data.service';
import { logServerError } from '../../../../../utils/serverLogger';
import { workoutIntentService } from '../../../workout_intent.service';

export interface ProposeWorkoutPlanInput {
  clientIdentifier: string;       // Name, AXG-XXXX, or UUID
  planTitle: string;              // e.g. "4-Week Hypertrophy Program"
  reason: string;                 // Why this plan suits the client
  summary: string;                // 1-2 sentence overview for admin
  weeklySchedule: {
    id?: string;
    dayId?: string;
    day: string;                  // "Monday", "Wednesday", etc.
    dayName?: string;
    weekday?: string;
    sessionTitle: string;         // "Upper Body Strength"
    title?: string;
    splitCategory?: string;
    category?: string;
    workoutType: string;          // "Strength" | "Hypertrophy" | "Cardio" etc.
    targetMuscleGroup: string;    // "Chest · Triceps · Shoulders"
    targetMuscles?: string[];
    estimatedDurationMinutes: number;
    recommendedExercisesCount?: number;
    exercises: Array<{
      exerciseId?: string;
      name: string;
      exerciseName?: string;
      category?: string;
      bodyPart?: string;
      orderIndex?: number;
      sets: number;
      numberOfSets?: number;
      reps: string;               // "8-12" or "15" or "30 sec"
      targetReps?: string;
      weight?: number | null;
      targetWeight?: number | null;
      restSeconds: number;
      targetRir?: number;
      targetRpe?: number;
      tempo?: string;
      notes?: string;             // Coaching cues
      adminInstruction?: string;
      day?: string;
    }>;
  }[];
}

export const proposeWorkoutPlanTool: ToolDefinition<ProposeWorkoutPlanInput> = {
  name: 'propose_workout_plan',
  description:
    'Saves a complete AI-generated personalized workout plan as a PENDING proposal for admin review and approval. ' +
    'Call this after reading the client profile, goals, fitness level, and injury status. ' +
    'The plan is NOT assigned to the client until the admin approves it. ' +
    'Include a weekly schedule with specific exercises, sets, reps, and rest periods.',
  category: 'PROPOSE',
  permission: ToolPermission.PROPOSE_PLAN,
  inputSchema: {
    type: 'object',
    properties: {
      clientIdentifier: {
        type: 'string',
        description: 'Client name, AXG-XXXX ID, or UUID',
        minLength: 1,
        maxLength: 100,
      },
      planTitle: {
        type: 'string',
        description: 'Short descriptive title for the plan, e.g. "4-Week Hypertrophy Program"',
        minLength: 3,
        maxLength: 120,
      },
      reason: {
        type: 'string',
        description: 'Evidence-based reason this plan suits the client based on their profile data',
        minLength: 1,
        maxLength: 800,
      },
      summary: {
        type: 'string',
        description: '1-2 sentence plain-language overview for the admin',
        minLength: 1,
        maxLength: 300,
      },
      weeklySchedule: {
        type: 'array',
        description: 'Array of workout days in the weekly plan',
        items: {
          type: 'object',
          properties: {
            day: { type: 'string', description: 'Day of the week e.g. Monday' },
            sessionTitle: { type: 'string', description: 'Session name e.g. Upper Body Strength' },
            workoutType: { type: 'string', description: 'Type of workout e.g. Strength, Hypertrophy, Cardio' },
            targetMuscleGroup: { type: 'string', description: 'Target muscle groups e.g. Chest · Triceps' },
            estimatedDurationMinutes: { type: 'number', description: 'Estimated session duration in minutes' },
            exercises: {
              type: 'array',
              description: 'List of exercises for this session',
              items: {
                type: 'object',
                properties: {
                  name: { type: 'string', description: 'Exercise name' },
                  sets: { type: 'number', description: 'Number of sets' },
                  reps: { type: 'string', description: 'Rep range e.g. 8-12 or 30 sec' },
                  restSeconds: { type: 'number', description: 'Rest between sets in seconds' },
                  notes: { type: 'string', description: 'Optional coaching cues' },
                },
              } as any,
            },
          },
        } as any,
      },
      exercises: {
        type: 'array',
        description: 'Optional top-level list of exercises for a single-day workout session',
        items: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Exercise name' },
            sets: { type: 'number', description: 'Number of sets' },
            reps: { type: 'string', description: 'Rep range e.g. 8-12 or 30 sec' },
            restSeconds: { type: 'number', description: 'Rest between sets in seconds' },
            notes: { type: 'string', description: 'Optional coaching cues' },
          },
        } as any,
      },
      workoutType: { type: 'string', description: 'Optional workout type e.g. Hypertrophy, Strength' },
      targetMuscleGroup: { type: 'string', description: 'Optional target muscles e.g. Back · Biceps' },
      estimatedDurationMinutes: { type: 'number', description: 'Optional estimated duration in minutes' },
      day: { type: 'string', description: 'Optional target day e.g. Tuesday' },
    },
    required: ['clientIdentifier', 'planTitle'],
  },
  handler: async (args: ProposeWorkoutPlanInput, context: ToolExecutionContext) => {
    try {
      // 1. Validate and normalize required fields
      if (!args.clientIdentifier || typeof args.clientIdentifier !== 'string' || !args.clientIdentifier.trim()) {
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: 'Client identifier is required.',
        };
      }

      if (!args.planTitle || typeof args.planTitle !== 'string' || args.planTitle.trim().length < 3) {
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: 'Plan title must be at least 3 characters long.',
        };
      }

      if (!args.reason || typeof args.reason !== 'string' || args.reason.trim().length === 0) {
        args.reason = `Programmed for client profile (${args.clientIdentifier}) based on fitness assessment and training goals.`;
      } else if (args.reason.trim().length < 10) {
        args.reason = `${args.reason.trim()} — tailored for athlete profile.`;
      }

      if (!args.summary || typeof args.summary !== 'string' || args.summary.trim().length === 0) {
        args.summary = `Personalized ${args.planTitle} workout session for ${args.clientIdentifier}.`;
      } else if (args.summary.trim().length < 10) {
        args.summary = `${args.summary.trim()} workout proposal.`;
      }

      // Automatically construct weeklySchedule if top-level exercises were passed
      const rawAny = args as any;
      if (
        (!Array.isArray(args.weeklySchedule) || args.weeklySchedule.length === 0) &&
        Array.isArray(rawAny.exercises) &&
        rawAny.exercises.length > 0
      ) {
        args.weeklySchedule = [
          {
            day: rawAny.day || 'Workout Day',
            sessionTitle: rawAny.sessionTitle || args.planTitle,
            workoutType: rawAny.workoutType || 'Hypertrophy',
            targetMuscleGroup: rawAny.targetMuscleGroup || 'Full Body',
            estimatedDurationMinutes: Number(rawAny.estimatedDurationMinutes) || 45,
            exercises: rawAny.exercises,
          },
        ];
      }

      if (!Array.isArray(args.weeklySchedule) || args.weeklySchedule.length === 0) {
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: 'Weekly schedule or exercises must include at least one workout day with scheduled exercises.',
        };
      }

    let totalExerciseCount = 0;
    for (let dIdx = 0; dIdx < args.weeklySchedule.length; dIdx++) {
      const day = args.weeklySchedule[dIdx];
      if (!day || !day.day || typeof day.day !== 'string') {
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: `Scheduled day ${dIdx + 1} must have a valid day name.`,
        };
      }

      const isRestDay = /rest|recovery/i.test(day.sessionTitle || '') || /rest|recovery/i.test(day.workoutType || '');
      if (!Array.isArray(day.exercises) || day.exercises.length === 0) {
        if (isRestDay) {
          day.exercises = [];
          continue;
        }
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: `Scheduled day ${dIdx + 1} (${day.day}) must contain at least one exercise.`,
        };
      }

      for (let eIdx = 0; eIdx < day.exercises.length; eIdx++) {
        const ex = day.exercises[eIdx] as any;
        const exName = ex?.name || ex?.exerciseName;
        const exSets = Number(ex?.sets !== undefined ? ex?.sets : ex?.numberOfSets);
        const exReps = ex?.reps !== undefined ? String(ex.reps) : (ex?.targetReps !== undefined ? String(ex.targetReps) : '8-10');

        if (!ex || !exName || !exName.trim() || isNaN(exSets) || exSets < 1) {
          return {
            success: false,
            source: 'ALPHA_X_DATABASE',
            error: 'VALIDATION_ERROR',
            message: `Exercise ${eIdx + 1} on ${day.day} must have a valid name and sets (>= 1).`,
          };
        }

        // Normalize onto exercise object
        ex.name = exName.trim();
        ex.sets = exSets;
        ex.reps = exReps.trim();
        ex.restSeconds = Number(ex.restSeconds) || 90;
        totalExerciseCount++;
      }
    }

    if (totalExerciseCount === 0) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: 'VALIDATION_ERROR',
        message: 'Workout plan must contain at least one scheduled exercise.',
      };
    }

    // 2. Resolve client
    const resolved = await clientDataService.resolveClient(args.clientIdentifier.trim());
    if (resolved.status !== 'FOUND' || !resolved.client) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: resolved.status === 'AMBIGUOUS'
          ? 'MULTIPLE_CLIENTS_FOUND — please specify the exact client AXG ID'
          : 'CLIENT_NOT_FOUND',
        message: resolved.message || `No client found matching '${args.clientIdentifier}'.`,
      };
    }

    const { profileId, clientId, name } = resolved.client;

    // 3. Detect split and perform workout quality & muscle group validation
    const splitDetectorInput = `${args.planTitle} ${args.weeklySchedule[0]?.targetMuscleGroup || ''} ${args.weeklySchedule[0]?.sessionTitle || ''} ${args.summary || ''} ${args.reason || ''}`;
    const splitResult = workoutIntentService.detectSplit(splitDetectorInput);

    if (splitResult.isAmbiguous) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: 'AMBIGUOUS_SPLIT_ERROR',
        message: splitResult.ambiguityReason || 'Ambiguous workout split detected. Please specify a single coherent split (e.g. Chest Day, Pull Day, Leg Day).',
      };
    }

    // 4. Build and validate exercise items against the Alpha X Exercise Catalog
    const rawExercises = args.weeklySchedule.flatMap((day, dIdx) =>
      (day.exercises || []).map((ex: any, eIdx: number) => ({
        exerciseId: ex.exerciseId,
        exerciseName: ex.name || ex.exerciseName,
        name: ex.name || ex.exerciseName,
        category: day.workoutType || 'Strength',
        bodyPart: ex.bodyPart,
        orderIndex: eIdx,
        sets: Number(ex.sets) || 3,
        numberOfSets: Number(ex.sets) || 3,
        targetReps: String(ex.reps || '8-10'),
        reps: String(ex.reps || '8-10'),
        targetWeight: ex.weight !== undefined ? Number(ex.weight) : (ex.targetWeight !== undefined ? Number(ex.targetWeight) : null),
        restSeconds: Number(ex.restSeconds) || 90,
        targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : 2,
        targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : 8.0,
        tempo: ex.tempo || '3-1-1-0',
        notes: ex.notes || null,
        day: day.day,
      }))
    );

    const validation = await workoutIntentService.validateProposalForSplit(splitResult, rawExercises, args.weeklySchedule);
    if (!validation.isValid) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: 'SPLIT_VALIDATION_ERROR',
        message: validation.error || `Exercises do not match the requested ${splitResult.split} split.`,
      };
    }

    const validatedExercises = validation.validatedExercises;

    // Update weekly schedule exercises with validated items while preserving day structure
    let validatedIdx = 0;
    const validatedWeeklySchedule = args.weeklySchedule.map((day, dIdx) => {
      const dayId = day.id || day.dayId || `day_${dIdx + 1}`;
      const dayName = day.day || day.dayName || day.weekday || `Day ${dIdx + 1}`;
      const splitCat = day.splitCategory || day.category || (day.sessionTitle && day.sessionTitle.includes('Pull') ? 'Pull' : (day.sessionTitle && day.sessionTitle.includes('Leg') ? 'Legs' : 'Push'));

      return {
        ...day,
        id: dayId,
        dayId,
        day: dayName,
        dayName,
        weekday: dayName,
        splitCategory: splitCat,
        category: splitCat,
        sessionTitle: day.sessionTitle || day.title || `${splitCat} Day`,
        title: day.sessionTitle || day.title || `${splitCat} Day`,
        workoutType: day.workoutType || 'Hypertrophy',
        targetMuscleGroup: day.targetMuscleGroup || (splitResult.isMultiDayTemplate ? (day.sessionTitle || 'Full Body') : splitResult.targetMuscleGroup),
        targetMuscles: day.targetMuscles || [day.targetMuscleGroup || 'Full Body'],
        estimatedDurationMinutes: Number(day.estimatedDurationMinutes) || 50,
        recommendedExercisesCount: (day.exercises || []).length,
        exercises: (day.exercises || []).map((ex: any, exIdx: number) => {
          const v = validatedExercises[validatedIdx++];
          return {
            ...ex,
            exerciseId: v ? v.exerciseId : ex.exerciseId,
            name: v ? v.name : ex.name,
            exerciseName: v ? v.name : (ex.exerciseName || ex.name),
            category: v ? v.category : (ex.category || day.workoutType || 'Strength'),
            bodyPart: v ? v.bodyPart : ex.bodyPart,
            orderIndex: ex.orderIndex !== undefined ? ex.orderIndex : exIdx,
            sets: Number(ex.sets || ex.numberOfSets) || 3,
            numberOfSets: Number(ex.sets || ex.numberOfSets) || 3,
            reps: String(ex.reps || ex.targetReps || '8-10'),
            targetReps: String(ex.targetReps || ex.reps || '8-10'),
            weight: ex.weight !== undefined ? Number(ex.weight) : (ex.targetWeight !== undefined ? Number(ex.targetWeight) : null),
            targetWeight: ex.targetWeight !== undefined ? Number(ex.targetWeight) : (ex.weight !== undefined ? Number(ex.weight) : null),
            restSeconds: Number(ex.restSeconds || ex.rest) || 90,
            targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : (ex.rir !== undefined ? Number(ex.rir) : 2),
            targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : (ex.rpe !== undefined ? Number(ex.rpe) : 8.0),
            tempo: ex.tempo || '3-1-1-0',
            notes: ex.notes || ex.adminInstruction || null,
            adminInstruction: ex.adminInstruction || ex.notes || null,
            day: dayName,
          };
        }),
      };
    });

    const isMultiDaySplit = validatedWeeklySchedule.length > 1;
    const proposedPayload = {
      title: args.planTitle,
      planTitle: args.planTitle,
      workoutType: validatedWeeklySchedule[0]?.workoutType || 'Hypertrophy',
      targetMuscleGroup: splitResult.split !== 'GENERAL' ? splitResult.targetMuscleGroup : (validatedWeeklySchedule[0]?.targetMuscleGroup || 'Full Body'),
      difficulty: 'Intermediate',
      estimatedDurationMinutes: Number(validatedWeeklySchedule[0]?.estimatedDurationMinutes) || 50,
      description: args.summary,
      isMultiDaySplit,
      totalDays: validatedWeeklySchedule.length,
      weeklySchedule: validatedWeeklySchedule,
      exercises: validatedExercises,
      generatedAt: new Date().toISOString(),
      generatedByAdminId: context.adminId,
    };

    try {
      // 5. Safely resolve conversationId to prevent foreign key violations
      let validConversationId: string | null = null;
      if (context.conversationId) {
        const convExists = await prisma.aIConversation.findUnique({
          where: { id: context.conversationId },
          select: { id: true },
        });
        if (convExists) {
          validConversationId = convExists.id;
        }
      }

      // Prevent duplicate proposals caused by retries or repeated tool calls for the SAME plan
      const existing = await prisma.aIProposal.findFirst({
        where: {
          clientProfileId: profileId,
          proposalType: 'WORKOUT',
          status: 'PENDING',
          title: args.planTitle,
          ...(validConversationId ? { conversationId: validConversationId } : {}),
        },
        orderBy: { createdAt: 'desc' },
      });

      let proposal;
      if (existing) {
        proposal = await prisma.aIProposal.update({
          where: { id: existing.id },
          data: {
            title: args.planTitle,
            summary: args.summary,
            reason: args.reason,
            proposedDataJson: JSON.stringify(proposedPayload),
            updatedAt: new Date(),
          },
          select: { id: true, title: true, status: true, createdAt: true },
        });
      } else {
        proposal = await prisma.aIProposal.create({
          data: {
            conversationId: validConversationId,
            clientProfileId: profileId,
            clientId: clientId || null,
            clientName: name,
            proposalType: 'WORKOUT',
            status: 'PENDING',
            title: args.planTitle,
            summary: args.summary,
            reason: args.reason,
            proposedDataJson: JSON.stringify(proposedPayload),
          },
          select: { id: true, title: true, status: true, createdAt: true },
        });
      }

      return {
        success: true,
        source: 'ALPHA_X_DATABASE',
        message: `Workout plan proposal saved for admin review`,
        proposalId: proposal.id,
        status: 'PENDING',
        clientName: name,
        planTitle: args.planTitle,
        note: 'The admin must approve this proposal before it is assigned to the client. Tell the admin they can review it in the AI Proposals section.',
        proposal: {
          id: proposal.id,
          clientId: clientId || profileId,
          clientName: name,
          type: 'WORKOUT',
          title: args.planTitle,
          summary: args.summary,
          reason: args.reason,
          status: 'PENDING',
          payload: proposedPayload,
        },
      };
    } catch (dbErr: any) {
      logServerError({
        requestId: context.requestId,
        activity: 'Propose Workout Plan DB Persistence',
        error: dbErr,
        errorMessage: dbErr?.message || String(dbErr),
        clientId: clientId || profileId,
        details: { planTitle: args.planTitle, conversationId: context.conversationId },
      });
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: 'DATABASE_ERROR',
        message: `Failed to save workout plan proposal to database: ${dbErr?.message || String(dbErr)}`,
      };
    }
  } catch (outerErr: any) {
    logServerError({
      requestId: context?.requestId,
      activity: 'Propose Workout Plan Tool Handler',
      error: outerErr,
      errorMessage: outerErr?.message || String(outerErr),
      details: { planTitle: args?.planTitle, conversationId: context?.conversationId },
    });
    return {
      success: false,
      source: 'ALPHA_X_DATABASE',
      error: 'UNEXPECTED_ERROR',
      message: `Failed to process workout plan proposal: ${outerErr?.message || String(outerErr)}`,
    };
  }
},
  enabled: true,
};

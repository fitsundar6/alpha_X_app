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

export interface ProposeWorkoutPlanInput {
  clientIdentifier: string;       // Name, AXG-XXXX, or UUID
  planTitle: string;              // e.g. "4-Week Hypertrophy Program"
  reason: string;                 // Why this plan suits the client
  summary: string;                // 1-2 sentence overview for admin
  weeklySchedule: {
    day: string;                  // "Monday", "Wednesday", etc.
    sessionTitle: string;         // "Upper Body Strength"
    workoutType: string;          // "Strength" | "Hypertrophy" | "Cardio" etc.
    targetMuscleGroup: string;    // "Chest · Triceps · Shoulders"
    estimatedDurationMinutes: number;
    exercises: Array<{
      name: string;
      sets: number;
      reps: string;               // "8-12" or "15" or "30 sec"
      restSeconds: number;
      notes?: string;             // Coaching cues
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
        minLength: 10,
        maxLength: 800,
      },
      summary: {
        type: 'string',
        description: '1-2 sentence plain-language overview for the admin',
        minLength: 10,
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
    },
    required: ['clientIdentifier', 'planTitle', 'reason', 'summary', 'weeklySchedule'],
    additionalProperties: false,
  },
  handler: async (args: ProposeWorkoutPlanInput, context: ToolExecutionContext) => {
    // 1. Resolve client
    const resolved = await clientDataService.resolveClient(args.clientIdentifier);
    if (resolved.status !== 'FOUND' || !resolved.client) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: resolved.status === 'AMBIGUOUS'
          ? 'MULTIPLE_CLIENTS_FOUND — please specify the exact client AXG ID'
          : 'CLIENT_NOT_FOUND',
        message: resolved.message,
      };
    }

    const { profileId, clientId, name } = resolved.client;

    // 2. Save proposal to DB (status: PENDING — admin must approve)
    const proposal = await prisma.aIProposal.create({
      data: {
        conversationId: context.conversationId || null,
        clientProfileId: profileId,
        clientId: clientId || null,
        clientName: name,
        proposalType: 'WORKOUT',
        status: 'PENDING',
        title: args.planTitle,
        summary: args.summary,
        reason: args.reason,
        proposedDataJson: JSON.stringify({
          planTitle: args.planTitle,
          weeklySchedule: args.weeklySchedule,
          generatedAt: new Date().toISOString(),
          generatedByAdminId: context.adminId,
        }),
      },
      select: { id: true, title: true, status: true, createdAt: true },
    });

    return {
      success: true,
      source: 'ALPHA_X_DATABASE',
      message: `Workout plan proposal saved for admin review`,
      proposalId: proposal.id,
      status: 'PENDING_ADMIN_APPROVAL',
      clientName: name,
      planTitle: args.planTitle,
      note: 'The admin must approve this proposal before it is assigned to the client. Tell the admin they can review it in the AI Proposals section.',
    };
  },
  enabled: true,
};

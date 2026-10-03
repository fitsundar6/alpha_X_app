/**
 * Alpha X AI — Tool: propose_diet_plan
 * Phase 7 — AI Plan Proposal Engine
 *
 * The AI calls this tool to save a proposed diet plan for admin review.
 * The plan is NEVER assigned to the client until the admin explicitly approves it.
 */

import { ToolDefinition, ToolPermission, ToolExecutionContext } from '../../tool.types';
import { prisma } from '../../../../../config/prisma';
import { clientDataService } from '../client/client_data.service';

export interface ProposeDietPlanInput {
  clientIdentifier: string;
  planName: string;               // e.g. "High-Protein Fat Loss Plan"
  reason: string;                 // Why this diet suits the client
  summary: string;                // 1-2 sentence overview for admin
  dailyCalories: number;
  protein: number;                // grams
  carbohydrates: number;          // grams
  fat: number;                    // grams
  fiber: number;                  // grams
  waterTargetLiters: number;
  mealSuggestions?: Array<{
    mealName: string;             // "Breakfast", "Lunch", "Post-Workout"
    targetCalories: number;
    targetProtein: number;
    foods: string[];              // Simple list: ["3 eggs", "oats 80g", "banana"]
  }>;
  notes?: string;                 // Any coaching notes
}

export const proposeDietPlanTool: ToolDefinition<ProposeDietPlanInput> = {
  name: 'propose_diet_plan',
  description:
    'Saves a complete AI-generated personalized diet plan as a PENDING proposal for admin review and approval. ' +
    'Call this after reading the client profile, current weight, goals, and assigned diet history. ' +
    'The plan is NOT assigned to the client until the admin approves it. ' +
    'Provide daily macro targets (calories, protein, carbs, fat, fiber, water) and optional meal suggestions.',
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
      planName: {
        type: 'string',
        description: 'Short descriptive name, e.g. "High-Protein Fat Loss Plan"',
        minLength: 3,
        maxLength: 120,
      },
      reason: {
        type: 'string',
        description: 'Evidence-based reason this diet suits the client based on their data',
        minLength: 10,
        maxLength: 800,
      },
      summary: {
        type: 'string',
        description: '1-2 sentence plain-language overview for the admin',
        minLength: 10,
        maxLength: 300,
      },
      dailyCalories: {
        type: 'number',
        description: 'Total daily calorie target',
        minimum: 800,
        maximum: 6000,
      },
      protein: {
        type: 'number',
        description: 'Daily protein target in grams',
        minimum: 40,
        maximum: 500,
      },
      carbohydrates: {
        type: 'number',
        description: 'Daily carbohydrate target in grams',
        minimum: 0,
        maximum: 1000,
      },
      fat: {
        type: 'number',
        description: 'Daily fat target in grams',
        minimum: 20,
        maximum: 400,
      },
      fiber: {
        type: 'number',
        description: 'Daily fiber target in grams',
        minimum: 10,
        maximum: 80,
      },
      waterTargetLiters: {
        type: 'number',
        description: 'Daily water intake target in liters',
        minimum: 1,
        maximum: 6,
      },
      mealSuggestions: {
        type: 'array',
        description: 'Optional suggested meals per day',
        items: { type: 'object' },
      },
      notes: {
        type: 'string',
        description: 'Optional coaching notes or dietary restrictions to highlight',
        maxLength: 500,
      },
    },
    required: ['clientIdentifier', 'planName', 'reason', 'summary', 'dailyCalories', 'protein', 'carbohydrates', 'fat', 'fiber', 'waterTargetLiters'],
    additionalProperties: false,
  },
  handler: async (args: ProposeDietPlanInput, context: ToolExecutionContext) => {
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

    // 2. Save proposal to DB (status: PENDING)
    const proposal = await prisma.aIProposal.create({
      data: {
        conversationId: context.conversationId || null,
        clientProfileId: profileId,
        clientId: clientId || null,
        clientName: name,
        proposalType: 'DIET',
        status: 'PENDING',
        title: args.planName,
        summary: args.summary,
        reason: args.reason,
        proposedDataJson: JSON.stringify({
          planName: args.planName,
          dailyCalories: args.dailyCalories,
          protein: args.protein,
          carbohydrates: args.carbohydrates,
          fat: args.fat,
          fiber: args.fiber,
          waterTargetLiters: args.waterTargetLiters,
          mealSuggestions: args.mealSuggestions || [],
          notes: args.notes || '',
          generatedAt: new Date().toISOString(),
          generatedByAdminId: context.adminId,
        }),
      },
      select: { id: true, title: true, status: true, createdAt: true },
    });

    return {
      success: true,
      source: 'ALPHA_X_DATABASE',
      message: `Diet plan proposal saved for admin review`,
      proposalId: proposal.id,
      status: 'PENDING_ADMIN_APPROVAL',
      clientName: name,
      planName: args.planName,
      macroSummary: {
        calories: args.dailyCalories,
        proteinG: args.protein,
        carbsG: args.carbohydrates,
        fatG: args.fat,
      },
      note: 'The admin must approve this proposal before it is assigned to the client. Tell the admin they can review it in the AI Proposals section.',
    };
  },
  enabled: true,
};

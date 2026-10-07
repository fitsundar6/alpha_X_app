/**
 * Alpha X AI — Tool: analyze_client_meal_breakdown
 * Phase 10 — Nutrition Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { nutritionIntelligenceService } from '../../../nutrition_intelligence/nutrition_intelligence.service';

export interface AnalyzeClientMealBreakdownInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const analyzeClientMealBreakdownTool: ToolDefinition<AnalyzeClientMealBreakdownInput> = {
  name: 'analyze_client_meal_breakdown',
  description: 'Analyzes client meal composition patterns, showing how calories and macronutrients are distributed across meal types (Breakfast, Lunch, Dinner, Snacks), average calories per meal, and top consumed food items in each meal.',
  category: 'ANALYZE',
  permission: ToolPermission.ANALYZE_DATA,
  inputSchema: {
    type: 'object',
    properties: {
      clientId: {
        type: 'string',
        description: 'The unique client identifier (AXG ID, User UUID, or exact client name)',
        minLength: 1,
        maxLength: 100,
      },
      startDate: {
        type: 'string',
        description: 'Start date filter in YYYY-MM-DD format (optional)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      endDate: {
        type: 'string',
        description: 'End date filter in YYYY-MM-DD format (optional)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      limit: {
        type: 'integer',
        description: 'Maximum number of food log records to process (default: 300, max: 500)',
        minimum: 1,
        maximum: 500,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, context) => {
    const targetClientId = context?.verifiedClient ? context.verifiedClient.clientId : args.clientId;
    return await nutritionIntelligenceService.analyzeMealBreakdown(targetClientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

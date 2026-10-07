/**
 * Alpha X AI — Tool: get_client_nutrition_history
 * Phase 10 — Nutrition Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { nutritionIntelligenceService } from '../../../nutrition_intelligence/nutrition_intelligence.service';

export interface GetClientNutritionHistoryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const getClientNutritionHistoryTool: ToolDefinition<GetClientNutritionHistoryInput> = {
  name: 'get_client_nutrition_history',
  description: 'Retrieves client nutrition intake history across multiple days or weeks, returning chronological daily totals, weekly rollups, highest/lowest intake days, and detected trend direction for calories and protein (increasing, decreasing, stable).',
  category: 'READ',
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
    return await nutritionIntelligenceService.getNutritionHistory(targetClientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

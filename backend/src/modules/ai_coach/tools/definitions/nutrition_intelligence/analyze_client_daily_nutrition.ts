/**
 * Alpha X AI — Tool: analyze_client_daily_nutrition
 * Phase 10 — Nutrition Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { nutritionIntelligenceService } from '../../../nutrition_intelligence/nutrition_intelligence.service';

export interface AnalyzeClientDailyNutritionInput {
  clientId: string;
  date?: string; // YYYY-MM-DD (defaults to most recent logged date or today)
}

export const analyzeClientDailyNutritionTool: ToolDefinition<AnalyzeClientDailyNutritionInput> = {
  name: 'analyze_client_daily_nutrition',
  description: 'Analyzes client nutrition for a specific single calendar date, breaking down all meals (Breakfast, Lunch, Dinner, Snacks), individual food items with portion sizes, total calories/macros, and exact comparison to the daily assigned diet target.',
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
      date: {
        type: 'string',
        description: 'The specific calendar date to analyze in YYYY-MM-DD format (optional; defaults to most recent logged date)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, context) => {
    const targetClientId = context?.verifiedClient ? context.verifiedClient.clientId : args.clientId;
    return await nutritionIntelligenceService.analyzeDailyNutrition(targetClientId, args.date);
  },
  enabled: true,
};

/**
 * Alpha X AI — Tool: compare_client_nutrition_periods
 * Phase 10 — Nutrition Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { nutritionIntelligenceService } from '../../../nutrition_intelligence/nutrition_intelligence.service';

export interface CompareClientNutritionPeriodsInput {
  clientId: string;
  preset?: 'THIS_WEEK_VS_LAST_WEEK' | 'LAST_7_DAYS_VS_PREVIOUS_7_DAYS' | 'LAST_14_DAYS_VS_PREVIOUS_14_DAYS';
  p1StartDate?: string;
  p1EndDate?: string;
  p2StartDate?: string;
  p2EndDate?: string;
}

export const compareClientNutritionPeriodsTool: ToolDefinition<CompareClientNutritionPeriodsInput> = {
  name: 'compare_client_nutrition_periods',
  description: 'Compares client nutrition intake and macro adherence between two distinct periods (e.g. preset: "THIS_WEEK_VS_LAST_WEEK", "LAST_7_DAYS_VS_PREVIOUS_7_DAYS", "LAST_14_DAYS_VS_PREVIOUS_14_DAYS", or custom date ranges), calculating exact deltas and percentage changes in calories, protein, carbs, fat, and adherence.',
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
      preset: {
        type: 'string',
        description: 'Preset comparison window: "THIS_WEEK_VS_LAST_WEEK", "LAST_7_DAYS_VS_PREVIOUS_7_DAYS", or "LAST_14_DAYS_VS_PREVIOUS_14_DAYS"',
        enum: ['THIS_WEEK_VS_LAST_WEEK', 'LAST_7_DAYS_VS_PREVIOUS_7_DAYS', 'LAST_14_DAYS_VS_PREVIOUS_14_DAYS'],
      },
      p1StartDate: {
        type: 'string',
        description: 'Baseline Period 1 start date in YYYY-MM-DD format (for custom comparison)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      p1EndDate: {
        type: 'string',
        description: 'Baseline Period 1 end date in YYYY-MM-DD format (for custom comparison)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      p2StartDate: {
        type: 'string',
        description: 'Comparison Period 2 start date in YYYY-MM-DD format (for custom comparison)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      p2EndDate: {
        type: 'string',
        description: 'Comparison Period 2 end date in YYYY-MM-DD format (for custom comparison)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, context) => {
    const targetClientId = context?.verifiedClient ? context.verifiedClient.clientId : args.clientId;
    return await nutritionIntelligenceService.compareNutritionPeriods(targetClientId, {
      preset: args.preset,
      p1StartDate: args.p1StartDate,
      p1EndDate: args.p1EndDate,
      p2StartDate: args.p2StartDate,
      p2EndDate: args.p2EndDate,
    });
  },
  enabled: true,
};

/**
 * Alpha X AI — Tool: calculate_client_nutrition_summary
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { calculationService } from '../../../calculations/calculation.service';

export interface CalculateClientNutritionSummaryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  compareWithTarget?: boolean;
}

export const calculateClientNutritionSummaryTool: ToolDefinition<CalculateClientNutritionSummaryInput> = {
  name: 'calculate_client_nutrition_summary',
  description: 'Calculates deterministic aggregated nutrition intake and daily averages (calories, protein, carbohydrates, fat, fiber) from logged meals, and optionally compares actual intake with assigned coach diet targets.',
  category: 'ANALYZE',
  permission: ToolPermission.CALCULATE_METRIC,
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
      compareWithTarget: {
        type: 'boolean',
        description: 'If true, compares actual average intake against assigned coach diet plan targets',
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    if (args.compareWithTarget === true) {
      return await calculationService.calculateNutritionTargetComparison(args.clientId, {
        startDate: args.startDate,
        endDate: args.endDate,
      });
    }

    return await calculationService.calculateNutritionSummary(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
    });
  },
  enabled: true,
};

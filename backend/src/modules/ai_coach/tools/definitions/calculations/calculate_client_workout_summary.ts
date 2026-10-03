/**
 * Alpha X AI — Tool: calculate_client_workout_summary
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { calculationService } from '../../../calculations/calculation.service';

export interface CalculateClientWorkoutSummaryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const calculateClientWorkoutSummaryTool: ToolDefinition<CalculateClientWorkoutSummaryInput> = {
  name: 'calculate_client_workout_summary',
  description: 'Calculates deterministic workout volume load, average session volume, training duration in minutes, completed sets, and average RPE/RIR from completed workout records.',
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
      limit: {
        type: 'integer',
        description: 'Maximum number of workout records to process (default: 30, max: 100)',
        minimum: 1,
        maximum: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await calculationService.calculateWorkoutSummary(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

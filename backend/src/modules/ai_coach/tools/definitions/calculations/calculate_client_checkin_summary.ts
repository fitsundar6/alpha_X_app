/**
 * Alpha X AI — Tool: calculate_client_checkin_summary
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { calculationService } from '../../../calculations/calculation.service';

export interface CalculateClientCheckInSummaryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const calculateClientCheckInSummaryTool: ToolDefinition<CalculateClientCheckInSummaryInput> = {
  name: 'calculate_client_checkin_summary',
  description: 'Calculates deterministic weekly check-in metrics including average sleep hours, pain occurrence counts, average pain ratings, and adherence distributions. Never infers or diagnoses medical conditions.',
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
        description: 'Maximum number of check-in records to process (default: 20, max: 52)',
        minimum: 1,
        maximum: 52,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await calculationService.calculateCheckInSummary(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

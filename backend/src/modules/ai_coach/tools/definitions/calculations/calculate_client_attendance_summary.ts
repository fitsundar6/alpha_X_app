/**
 * Alpha X AI — Tool: calculate_client_attendance_summary
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { calculationService } from '../../../calculations/calculation.service';

export interface CalculateClientAttendanceSummaryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const calculateClientAttendanceSummaryTool: ToolDefinition<CalculateClientAttendanceSummaryInput> = {
  name: 'calculate_client_attendance_summary',
  description: 'Calculates deterministic gym attendance metrics (total sessions, present count, absent count, attendance percentage) strictly over recorded attendance logs.',
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
        description: 'Maximum number of attendance records to process (default: 60, max: 365)',
        minimum: 1,
        maximum: 365,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await calculationService.calculateAttendanceSummary(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

/**
 * Alpha X AI — Tool: get_client_workout_history
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetClientWorkoutHistoryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const getClientWorkoutHistoryTool: ToolDefinition<GetClientWorkoutHistoryInput> = {
  name: 'get_client_workout_history',
  description: 'Retrieves completed workout session records for an Alpha X client (exercises, completed sets, reps, load in kg, RPE, RIR, total volume). Read-only and bounded.',
  category: 'READ',
  permission: ToolPermission.READ_CLIENT,
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
        description: 'Maximum number of workout sessions to retrieve (default: 10, max: 30)',
        minimum: 1,
        maximum: 30,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getClientWorkoutHistory(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

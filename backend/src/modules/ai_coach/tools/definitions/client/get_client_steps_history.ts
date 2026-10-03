/**
 * Alpha X AI — Tool: get_client_steps_history
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetClientStepsHistoryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const getClientStepsHistoryTool: ToolDefinition<GetClientStepsHistoryInput> = {
  name: 'get_client_steps_history',
  description: 'Retrieves recorded daily step counts, step goals, cardio minutes, and active calorie burn for an Alpha X client within an optional validated date range.',
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
        description: 'Maximum number of days to retrieve (default: 14, max: 60)',
        minimum: 1,
        maximum: 60,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getClientStepsHistory(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

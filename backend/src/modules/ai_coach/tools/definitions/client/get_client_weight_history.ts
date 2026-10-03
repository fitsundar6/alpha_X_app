/**
 * Alpha X AI — Tool: get_client_weight_history
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetClientWeightHistoryInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const getClientWeightHistoryTool: ToolDefinition<GetClientWeightHistoryInput> = {
  name: 'get_client_weight_history',
  description: 'Retrieves historical body weight and waist measurement entries for an Alpha X client within an optional validated date range (YYYY-MM-DD, max span 365 days). Bounded to safe maximum limits.',
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
        description: 'Maximum number of records to retrieve (default: 20, max: 100)',
        minimum: 1,
        maximum: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getClientWeightHistory(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

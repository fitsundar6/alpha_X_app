/**
 * Alpha X AI — Tool: get_client_nutrition_log
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetClientNutritionLogInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const getClientNutritionLogTool: ToolDefinition<GetClientNutritionLogInput> = {
  name: 'get_client_nutrition_log',
  description: 'Retrieves actual logged food items consumed by an Alpha X client (meal type, food name, portion, calories, protein, carbs, fat, fiber). Distinct from assigned diet plans.',
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
        description: 'Maximum number of food entries to retrieve (default: 30, max: 100)',
        minimum: 1,
        maximum: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getClientNutritionLog(args.clientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

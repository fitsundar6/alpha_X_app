/**
 * Alpha X AI — Tool: get_assigned_diet
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetAssignedDietInput {
  clientId: string;
}

export const getAssignedDietTool: ToolDefinition<GetAssignedDietInput> = {
  name: 'get_assigned_diet',
  description: 'Retrieves the official coach-assigned diet plan currently active for an Alpha X client (target calories, macros, hydration, prescribed meals). Distinct from actual food logs.',
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
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getAssignedDiet(args.clientId);
  },
  enabled: true,
};

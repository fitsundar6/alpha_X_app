/**
 * Alpha X AI — Tool: get_client_checkins
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetClientCheckInsInput {
  clientId: string;
  limit?: number;
}

export const getClientCheckInsTool: ToolDefinition<GetClientCheckInsInput> = {
  name: 'get_client_checkins',
  description: 'Retrieves recorded weekly check-in entries submitted by an Alpha X client (week number, weight change, waist change, adherence, sleep, recovery, pain/injury notes).',
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
      limit: {
        type: 'integer',
        description: 'Maximum number of check-in entries to retrieve (default: 10, max: 20)',
        minimum: 1,
        maximum: 20,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getClientCheckIns(args.clientId, args.limit);
  },
  enabled: true,
};

/**
 * Alpha X AI — Tool: get_client_profile
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetClientProfileInput {
  clientId: string;
}

export const getClientProfileTool: ToolDefinition<GetClientProfileInput> = {
  name: 'get_client_profile',
  description: "Retrieves an Alpha X client's approved profile and assessment data (age, gender, height, current weight, fitness level, goals, injuries/surgeries, preferences) using their unique client identifier (AXG ID, UUID, or exact name). Excludes credentials, tokens, and internal secrets.",
  category: 'READ',
  permission: ToolPermission.READ_CLIENT,
  inputSchema: {
    type: 'object',
    properties: {
      clientId: {
        type: 'string',
        description: 'The unique client identifier (e.g. AXG-1001, User UUID, or exact client name)',
        minLength: 1,
        maxLength: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getClientProfile(args.clientId);
  },
  enabled: true,
};

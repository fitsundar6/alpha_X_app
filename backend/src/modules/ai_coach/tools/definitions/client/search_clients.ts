/**
 * Alpha X AI — Tool: search_clients
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface SearchClientsInput {
  query: string;
  limit?: number;
}

export const searchClientsTool: ToolDefinition<SearchClientsInput> = {
  name: 'search_clients',
  description: 'Searches for Alpha X clients by name, client ID (e.g. AXG-XXXX), or email. Returns matching clients with minimal identifying details to safely resolve client identity.',
  category: 'READ',
  permission: ToolPermission.READ_CLIENT,
  inputSchema: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'Client name, AXG-XXXX ID, or email search query',
        minLength: 1,
        maxLength: 100,
      },
      limit: {
        type: 'integer',
        description: 'Maximum number of client results to return (default: 10, max: 25)',
        minimum: 1,
        maximum: 25,
      },
    },
    required: ['query'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.searchClients(args.query, args.limit);
  },
  enabled: true,
};

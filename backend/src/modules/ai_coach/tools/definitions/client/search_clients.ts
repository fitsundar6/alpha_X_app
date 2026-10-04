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
  description: 'Searches for Alpha X clients by name, client ID (e.g. AXG-XXXX), or email. Pass an empty string or "all" to list all clients. Returns matching clients with minimal identifying details to safely resolve client identity.',
  category: 'READ',
  permission: ToolPermission.READ_CLIENT,
  inputSchema: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'Client name, AXG-XXXX ID, or email search query. Use empty string or "all" to list all clients.',
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
    // Treat empty / "all" as a broad search to list all clients
    const q = args.query?.trim() || '';
    const effectiveQuery = (q === '' || q.toLowerCase() === 'all') ? 'AXG' : q;
    return await clientDataService.searchClients(effectiveQuery, args.limit);
  },
  enabled: true,
};

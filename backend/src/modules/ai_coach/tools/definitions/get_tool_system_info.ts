/**
 * Alpha X AI — Tool: get_tool_system_info
 * Phase 5 — Safe Demonstration Tool
 */

import { ToolDefinition, ToolPermission } from '../tool.types';
import { toolRegistry } from '../tool.registry';
import { toolConfig } from '../tool.config';

export const getToolSystemInfoTool: ToolDefinition = {
  name: 'get_tool_system_info',
  description: 'Returns safe operational metadata about available AI tools, execution limits, and active security policies.',
  category: 'READ',
  permission: ToolPermission.READ_SYSTEM,
  inputSchema: {
    type: 'object',
    properties: {},
    required: [],
    additionalProperties: false,
  },
  handler: async (_args, _context) => {
    const tools = toolRegistry.listTools(true).map((t) => ({
      name: t.name,
      description: t.description,
      category: t.category,
      permission: t.permission,
      enabled: t.enabled,
    }));

    return {
      totalRegisteredTools: tools.length,
      tools,
      securityPolicies: {
        writeToolsAllowed: toolConfig.allowWriteTools,
        maxToolCallsPerTurn: toolConfig.maxToolCallsPerRequest,
        toolTimeoutMs: toolConfig.toolTimeoutMs,
        maxResultCharacters: toolConfig.maxResultCharacters,
        directDatabaseAccess: 'STRICTLY_PROHIBITED',
      },
    };
  },
  enabled: true,
};

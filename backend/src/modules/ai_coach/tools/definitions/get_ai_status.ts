/**
 * Alpha X AI — Tool: get_ai_status
 * Phase 5 — Safe Demonstration Tool
 */

import { ToolDefinition, ToolCategory, ToolPermission } from '../tool.types';
import { ALPHA_X_AI_PROMPT_VERSION } from '../../prompts/system_prompt';
import { knowledgeConfig, knowledgeStore } from '../../knowledge';

export const getAiStatusTool: ToolDefinition = {
  name: 'get_ai_status',
  description: 'Returns the current operational status, prompt version, knowledge base state, and tool framework readiness of the Alpha X AI system.',
  category: 'READ',
  permission: ToolPermission.READ_SYSTEM,
  inputSchema: {
    type: 'object',
    properties: {},
    required: [],
    additionalProperties: false,
  },
  handler: async (_args, _context) => {
    return {
      status: 'OPERATIONAL',
      system: 'Alpha X AI Coach',
      promptVersion: ALPHA_X_AI_PROMPT_VERSION,
      knowledgeRagEnabled: knowledgeConfig.isEnabled,
      verifiedKnowledgeDocumentsCount: knowledgeStore.getAll().length,
      toolFrameworkVersion: '5.0-ALPHA',
      environment: 'Alpha X Gym Intelligence Platform',
      activeCapabilities: [
        'Evidence-Informed Fitness Reasoning',
        'Curated Knowledge RAG',
        'Multi-Turn Conversational Memory',
        'Secure Tool Calling Framework',
      ],
    };
  },
  enabled: true,
};

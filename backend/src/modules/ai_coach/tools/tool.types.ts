/**
 * Alpha X AI — Tool & Function Calling System
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

export type ToolCategory = 'READ' | 'ANALYZE' | 'PROPOSE' | 'WRITE';

export enum ToolPermission {
  READ_SYSTEM = 'tool:read:system',
  READ_KNOWLEDGE = 'tool:read:knowledge',
  CALCULATE_METRIC = 'tool:calculate:metric',
  READ_CLIENT = 'tool:read:client',     // Reserved for Phase 6+
  ANALYZE_DATA = 'tool:analyze:data',   // Reserved for Phase 6+
  PROPOSE_PLAN = 'tool:propose:plan',   // Reserved for Phase 6+
  WRITE_DATA = 'tool:write:data',       // Reserved for future, strictly blocked in Phase 5
}

export interface ToolParameterProperty {
  type: 'string' | 'number' | 'integer' | 'boolean' | 'array' | 'object';
  description: string;
  enum?: string[];
  minimum?: number;
  maximum?: number;
  minLength?: number;
  maxLength?: number;
  pattern?: string;
  items?: {
    type: string;
  };
}

export interface ToolInputSchema {
  type: 'object';
  properties: Record<string, ToolParameterProperty>;
  required?: string[];
  additionalProperties?: boolean;
}

import type { VerifiedClientContext } from '../conversation/conversation.types';

export interface ToolExecutionContext {
  adminId: string;
  requestId: string;
  conversationId: string;
  callId?: string;
  verifiedClient?: VerifiedClientContext | null;
}

export interface ToolResult<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  toolName: string;
  latencyMs: number;
  metadata?: Record<string, any>;
}

export interface ToolDefinition<TArgs = any, TResult = any> {
  name: string;
  description: string;
  category: ToolCategory;
  permission: ToolPermission;
  inputSchema: ToolInputSchema;
  outputSchema?: Record<string, any>;
  handler: (args: TArgs, context: ToolExecutionContext) => Promise<TResult>;
  enabled: boolean;
}

/**
 * Machine-readable Gemini Function Declaration structure
 */
export interface GeminiFunctionDeclaration {
  name: string;
  description: string;
  parameters: {
    type: string;
    properties: Record<string, any>;
    required?: string[];
  };
}

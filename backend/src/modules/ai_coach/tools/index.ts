/**
 * Alpha X AI — Tool System Barrel & Initialization
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

export * from './tool.types';
export * from './tool.errors';
export * from './tool.config';
export * from './tool.permissions';
export * from './tool.validation';
export * from './tool.registry';
export * from './tool.executor';

import { toolRegistry } from './tool.registry';
import { getAiStatusTool } from './definitions/get_ai_status';
import { getFitnessTopicsTool } from './definitions/get_fitness_topics';
import { calculateSimpleTrainingExampleTool } from './definitions/calculate_training_example';
import { getToolSystemInfoTool } from './definitions/get_tool_system_info';
import { CLIENT_DATA_TOOLS } from './definitions/client';
import { CALCULATION_TOOLS } from './definitions/calculations';
import { WORKOUT_INTELLIGENCE_TOOLS } from './definitions/workout_intelligence';

export * from './definitions/client';
export * from './definitions/calculations';
export * from './definitions/workout_intelligence';

export const DEMO_TOOLS = [
  getAiStatusTool,
  getFitnessTopicsTool,
  calculateSimpleTrainingExampleTool,
  getToolSystemInfoTool,
];

export const ALL_DEFAULT_TOOLS = [
  ...DEMO_TOOLS,
  ...CLIENT_DATA_TOOLS,
  ...CALCULATION_TOOLS,
  ...WORKOUT_INTELLIGENCE_TOOLS,
];

/**
 * Initializes and registers the default baseline demonstration tools and client data tools
 */
export function initializeDefaultTools(): void {
  for (const tool of ALL_DEFAULT_TOOLS) {
    if (!toolRegistry.hasTool(tool.name)) {
      toolRegistry.register(tool);
    }
  }
}

/**
 * Resets the tool registry to standard baseline demonstration tools and client data tools
 */
export function resetToolsToDefault(): void {
  toolRegistry.clear();
  initializeDefaultTools();
}

// Auto-initialize baseline tools upon module load
initializeDefaultTools();


/**
 * Alpha X AI — Tool: get_client_personal_bests
 * Phase 9 — Workout Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { workoutIntelligenceService } from '../../../workout_intelligence/workout_intelligence.service';

export interface GetClientPersonalBestsInput {
  clientId: string;
  exerciseName?: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const getClientPersonalBestsTool: ToolDefinition<GetClientPersonalBestsInput> = {
  name: 'get_client_personal_bests',
  description: 'Retrieves deterministic personal best records (highest recorded weight, highest reps at top weight, highest single-session volume) for an exercise or all exercises based strictly on stored database records.',
  category: 'ANALYZE',
  permission: ToolPermission.ANALYZE_DATA,
  inputSchema: {
    type: 'object',
    properties: {
      clientId: {
        type: 'string',
        description: 'The unique client identifier (AXG ID, User UUID, or exact client name)',
        minLength: 1,
        maxLength: 100,
      },
      exerciseName: {
        type: 'string',
        description: 'Optional exercise name to filter PR records (e.g. "Bench Press", "Squat")',
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
        description: 'Maximum number of workout records to process (default: 100, max: 100)',
        minimum: 1,
        maximum: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, context) => {
    const targetClientId = context?.verifiedClient ? context.verifiedClient.clientId : args.clientId;
    return await workoutIntelligenceService.getPersonalBests(targetClientId, args.exerciseName);
  },
  enabled: true,
};

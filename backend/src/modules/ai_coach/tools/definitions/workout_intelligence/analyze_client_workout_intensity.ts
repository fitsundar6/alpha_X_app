/**
 * Alpha X AI — Tool: analyze_client_workout_intensity
 * Phase 9 — Workout Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { workoutIntelligenceService } from '../../../workout_intelligence/workout_intelligence.service';

export interface AnalyzeClientWorkoutIntensityInput {
  clientId: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export const analyzeClientWorkoutIntensityTool: ToolDefinition<AnalyzeClientWorkoutIntensityInput> = {
  name: 'analyze_client_workout_intensity',
  description: 'Analyzes factual RPE (Rate of Perceived Exertion) and RIR (Reps in Reserve) patterns, averages, extremes, and recorded distributions across completed workouts.',
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
        description: 'Maximum number of workout records to process (default: 50, max: 100)',
        minimum: 1,
        maximum: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, context) => {
    const targetClientId = context?.verifiedClient ? context.verifiedClient.clientId : args.clientId;
    return await workoutIntelligenceService.analyzeWorkoutIntensity(targetClientId, {
      startDate: args.startDate,
      endDate: args.endDate,
      limit: args.limit,
    });
  },
  enabled: true,
};

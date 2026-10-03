/**
 * Alpha X AI — Tool: compare_client_workout_periods
 * Phase 9 — Workout Intelligence Engine
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { workoutIntelligenceService } from '../../../workout_intelligence/workout_intelligence.service';

export interface CompareClientWorkoutPeriodsInput {
  clientId: string;
  preset?: 'last_7_days' | 'last_14_days' | 'last_28_days';
  currentStart?: string;
  currentEnd?: string;
  prevStart?: string;
  prevEnd?: string;
  period1Start?: string;
  period1End?: string;
  period2Start?: string;
  period2End?: string;
}

export const compareClientWorkoutPeriodsTool: ToolDefinition<CompareClientWorkoutPeriodsInput> = {
  name: 'compare_client_workout_periods',
  description: 'Compares client workout metrics (sessions, volume, frequency, sets, duration, intensity) between two periods (preset: "last_7_days", "last_14_days", "last_28_days", or custom non-overlapping date ranges).',
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
      preset: {
        type: 'string',
        description: 'Preset comparison window: "last_7_days" (last 7 vs prior 7), "last_14_days", or "last_28_days"',
        enum: ['last_7_days', 'last_14_days', 'last_28_days'],
      },
      currentStart: {
        type: 'string',
        description: 'Current/recent period start date (YYYY-MM-DD)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      currentEnd: {
        type: 'string',
        description: 'Current/recent period end date (YYYY-MM-DD)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      prevStart: {
        type: 'string',
        description: 'Prior/baseline period start date (YYYY-MM-DD)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      prevEnd: {
        type: 'string',
        description: 'Prior/baseline period end date (YYYY-MM-DD)',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      period1Start: {
        type: 'string',
        description: 'Prior/baseline period start date (YYYY-MM-DD) alias',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      period1End: {
        type: 'string',
        description: 'Prior/baseline period end date (YYYY-MM-DD) alias',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      period2Start: {
        type: 'string',
        description: 'Current/recent period start date (YYYY-MM-DD) alias',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
      period2End: {
        type: 'string',
        description: 'Current/recent period end date (YYYY-MM-DD) alias',
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, context) => {
    const targetClientId = context?.verifiedClient ? context.verifiedClient.clientId : args.clientId;
    return await workoutIntelligenceService.compareWorkoutPeriods(targetClientId, {
      preset: args.preset,
      currentStart: args.currentStart || args.period2Start,
      currentEnd: args.currentEnd || args.period2End,
      prevStart: args.prevStart || args.period1Start,
      prevEnd: args.prevEnd || args.period1End,
    });
  },
  enabled: true,
};

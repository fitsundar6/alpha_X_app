/**
 * Alpha X AI — Calculation Tools Barrel
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

export * from './calculate_client_weight_change';
export * from './calculate_client_waist_change';
export * from './calculate_client_nutrition_summary';
export * from './calculate_client_activity_summary';
export * from './calculate_client_workout_summary';
export * from './calculate_client_checkin_summary';

import { calculateClientWeightChangeTool } from './calculate_client_weight_change';
import { calculateClientWaistChangeTool } from './calculate_client_waist_change';
import { calculateClientNutritionSummaryTool } from './calculate_client_nutrition_summary';
import { calculateClientActivitySummaryTool } from './calculate_client_activity_summary';
import { calculateClientWorkoutSummaryTool } from './calculate_client_workout_summary';
import { calculateClientCheckInSummaryTool } from './calculate_client_checkin_summary';

export const CALCULATION_TOOLS = [
  calculateClientWeightChangeTool,
  calculateClientWaistChangeTool,
  calculateClientNutritionSummaryTool,
  calculateClientActivitySummaryTool,
  calculateClientWorkoutSummaryTool,
  calculateClientCheckInSummaryTool,
];

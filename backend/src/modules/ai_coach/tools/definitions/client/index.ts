/**
 * Alpha X AI — Client Data Tools Barrel
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

export * from './client_data.service';
export * from './search_clients';
export * from './get_client_profile';
export * from './get_client_weight_history';
export * from './get_client_workout_history';
export * from './get_client_nutrition_log';
export * from './get_assigned_diet';
export * from './get_client_checkins';
export * from './get_client_steps_history';
export * from './get_assigned_workout';
export * from './propose_workout_plan';
export * from './propose_diet_plan';

import { searchClientsTool } from './search_clients';
import { getClientProfileTool } from './get_client_profile';
import { getClientWeightHistoryTool } from './get_client_weight_history';
import { getClientWorkoutHistoryTool } from './get_client_workout_history';
import { getClientNutritionLogTool } from './get_client_nutrition_log';
import { getAssignedDietTool } from './get_assigned_diet';
import { getClientCheckInsTool } from './get_client_checkins';
import { getClientStepsHistoryTool } from './get_client_steps_history';
import { getAssignedWorkoutTool } from './get_assigned_workout';
import { proposeWorkoutPlanTool } from './propose_workout_plan';
import { proposeDietPlanTool } from './propose_diet_plan';

export const CLIENT_DATA_TOOLS = [
  searchClientsTool,
  getClientProfileTool,
  getClientWeightHistoryTool,
  getClientWorkoutHistoryTool,
  getClientNutritionLogTool,
  getAssignedDietTool,
  getClientCheckInsTool,
  getClientStepsHistoryTool,
  getAssignedWorkoutTool,
  proposeWorkoutPlanTool,
  proposeDietPlanTool,
];

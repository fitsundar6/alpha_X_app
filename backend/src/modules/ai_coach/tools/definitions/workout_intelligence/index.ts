/**
 * Alpha X AI — Phase 9: Workout Intelligence Tools
 * Barrel export of all Phase 9 tools
 */

import { ToolDefinition } from '../../tool.types';
import { analyzeClientWorkoutProgressTool } from './analyze_client_workout_progress';
import { analyzeClientExerciseProgressTool } from './analyze_client_exercise_progress';
import { analyzeClientTrainingFrequencyTool } from './analyze_client_training_frequency';
import { analyzeClientTrainingVolumeTool } from './analyze_client_training_volume';
import { analyzeClientWorkoutIntensityTool } from './analyze_client_workout_intensity';
import { compareClientWorkoutPeriodsTool } from './compare_client_workout_periods';
import { getClientPersonalBestsTool } from './get_client_personal_bests';

export * from './analyze_client_workout_progress';
export * from './analyze_client_exercise_progress';
export * from './analyze_client_training_frequency';
export * from './analyze_client_training_volume';
export * from './analyze_client_workout_intensity';
export * from './compare_client_workout_periods';
export * from './get_client_personal_bests';

export const WORKOUT_INTELLIGENCE_TOOLS: ToolDefinition[] = [
  analyzeClientWorkoutProgressTool as ToolDefinition,
  analyzeClientExerciseProgressTool as ToolDefinition,
  analyzeClientTrainingFrequencyTool as ToolDefinition,
  analyzeClientTrainingVolumeTool as ToolDefinition,
  analyzeClientWorkoutIntensityTool as ToolDefinition,
  compareClientWorkoutPeriodsTool as ToolDefinition,
  getClientPersonalBestsTool as ToolDefinition,
];

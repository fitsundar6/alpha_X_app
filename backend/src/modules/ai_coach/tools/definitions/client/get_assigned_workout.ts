/**
 * Alpha X AI — Tool: get_assigned_workout
 * Phase 6 — Secure Real Alpha X Client Data Access
 */

import { ToolDefinition, ToolPermission } from '../../tool.types';
import { clientDataService } from './client_data.service';

export interface GetAssignedWorkoutInput {
  clientId: string;
}

export const getAssignedWorkoutTool: ToolDefinition<GetAssignedWorkoutInput> = {
  name: 'get_assigned_workout',
  description: 'Retrieves the coach-assigned workout prescription and session structure currently assigned to an Alpha X client (target exercises, sets, reps, target load/RPE/tempo). Read-only.',
  category: 'READ',
  permission: ToolPermission.READ_CLIENT,
  inputSchema: {
    type: 'object',
    properties: {
      clientId: {
        type: 'string',
        description: 'The unique client identifier (AXG ID, User UUID, or exact client name)',
        minLength: 1,
        maxLength: 100,
      },
    },
    required: ['clientId'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    return await clientDataService.getAssignedWorkout(args.clientId);
  },
  enabled: true,
};

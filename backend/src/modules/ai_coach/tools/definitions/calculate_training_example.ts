/**
 * Alpha X AI — Tool: calculate_simple_training_example
 * Phase 5 — Safe Demonstration Tool (Deterministic Calculation Principle)
 */

import { ToolDefinition, ToolPermission } from '../tool.types';

export interface TrainingExampleInput {
  sets: number;
  reps: number;
  weightKg: number;
}

export const calculateSimpleTrainingExampleTool: ToolDefinition<TrainingExampleInput> = {
  name: 'calculate_simple_training_example',
  description: 'Calculates deterministic training metrics (total repetitions, total volume load in kg, and average load per set) from provided parameters.',
  category: 'ANALYZE',
  permission: ToolPermission.CALCULATE_METRIC,
  inputSchema: {
    type: 'object',
    properties: {
      sets: {
        type: 'integer',
        description: 'Number of working sets performed',
        minimum: 1,
        maximum: 100,
      },
      reps: {
        type: 'integer',
        description: 'Number of repetitions completed per set',
        minimum: 1,
        maximum: 200,
      },
      weightKg: {
        type: 'number',
        description: 'External load or resistance in kilograms',
        minimum: 0,
        maximum: 1000,
      },
    },
    required: ['sets', 'reps', 'weightKg'],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    const sets = Math.round(args.sets);
    const reps = Math.round(args.reps);
    const weightKg = Number(args.weightKg);

    const totalReps = sets * reps;
    const trainingVolumeKg = totalReps * weightKg;

    return {
      protocol: `${sets} sets × ${reps} reps @ ${weightKg} kg`,
      totalReps,
      trainingVolumeKg,
      averageIntensityKg: weightKg,
      calculationType: 'DETERMINISTIC_BACKEND_FORMULA',
      explanation: `Calculated as: ${sets} sets × ${reps} reps = ${totalReps} total reps; ${totalReps} reps × ${weightKg} kg = ${trainingVolumeKg} kg volume load.`,
    };
  },
  enabled: true,
};

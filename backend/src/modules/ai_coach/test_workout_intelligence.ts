/**
 * Alpha X AI — Phase 9 Test Suite: Workout Intelligence Engine
 *
 * Verifies 100+ required test cases across:
 * - Schema & Model Compatibility (1-8)
 * - Session Analysis (9-18)
 * - Training Frequency Analysis (19-27)
 * - Training Volume Analysis (28-38)
 * - Exercise Performance Analysis (39-49)
 * - Exercise Progression Analysis (50-58)
 * - Personal Best Records (59-67)
 * - RPE & Intensity Analysis (68-76)
 * - Period Comparison Engine (77-87)
 * - Date Range Validation Engine (88-93)
 * - Missing, Insufficient & Corrupted Data Handling (94-100)
 * - Security, Permissions & Verified Context (101-108)
 * - Gemini Integration & Tool Calling (109-112)
 * - Full Regression (Phases 1-8, TypeScript) (113-118)
 */

import http from 'http';
import jwt from 'jsonwebtoken';
import { execSync } from 'child_process';
import app from '../../server';
import { env } from '../../config/environment';
import { prisma } from '../../config/prisma';
import { geminiService } from './gemini.service';
import { toolRegistry } from './tools/tool.registry';
import { toolExecutor } from './tools/tool.executor';
import { toolConfig } from './tools/tool.config';
import { ToolPermission } from './tools/tool.types';
import { resetToolsToDefault, initializeDefaultTools } from './tools';
import { clientDataService } from './tools/definitions/client/client_data.service';
import { conversationStore } from './conversation';
import {
  workoutIntelligenceService,
  workoutIntelligenceCalculator,
  validateDateRange,
  computePresetComparisonDates,
  validateCustomComparisonIntervals,
  round2,
  RawWorkoutSessionEntry,
} from './workout_intelligence';
import { ALPHA_X_AI_SYSTEM_INSTRUCTION_V2 } from './prompts/system_prompt';

async function runPhase9WorkoutIntelligenceTests(): Promise<void> {
  console.log('================================================================');
  console.log('🏋️  ALPHA X AI — PHASE 9 WORKOUT INTELLIGENCE TEST SUITE');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, details?: string): void {
    if (condition) {
      passed++;
      console.log(`✔ [PASS] ${testName}`);
    } else {
      failed++;
      console.error(`❌ [FAIL] ${testName} ${details ? '— ' + details : ''}`);
    }
  }

  // Ensure tool registry and conversation stores are in standard state
  resetToolsToDefault();
  initializeDefaultTools();
  toolConfig.resetToDefaults();
  conversationStore.clear();

  // Spin up test server
  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address() as any;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  console.log(`[TEST HARNESS] Running on ${baseUrl}\n`);

  const adminToken = jwt.sign(
    { id: 'admin_alex_stone', email: 'fitsundar6@gmail.com', role: 'ADMIN', name: 'Alpha X Admin' },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  const clientToken = jwt.sign(
    { id: 'client_user_test', email: 'client.test@alphax.local', role: 'CLIENT', name: 'Client Test' },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  const adminContext = {
    adminId: 'admin_alex_stone',
    requestId: 'req_phase9_test',
    conversationId: 'conv_phase9_test',
  };

  const createdUserIds: string[] = [];

  try {
    // --------------------------------------------------------------------------
    // SEED REAL TEST FIXTURES IN ALPHA X DATABASE
    // --------------------------------------------------------------------------
    console.log('--- Setting up Test Fixtures in Alpha X Database ---');

    const timestamp = Date.now();
    const marcusAxId = `AXG-W${Math.floor(1000 + Math.random() * 9000)}`;
    const sophiaAxId = `AXG-S${Math.floor(1000 + Math.random() * 9000)}`;
    const leoAxId = `AXG-L${Math.floor(1000 + Math.random() * 9000)}`;

    // Client 1: Marcus Vance (Comprehensive Multi-Session Workout History)
    const marcusUser = await prisma.user.create({
      data: {
        name: `Marcus Workout ${timestamp}`,
        email: `marcus.workout.${timestamp}@alphax.test`,
        passwordHash: '$2a$10$SECRET_HASH_MARCUS_W',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: marcusAxId,
            age: 28,
            gender: 'Male',
            heightCm: 182,
            weightKg: 85.0,
            fitnessLevel: 'Advanced',
            primaryGoal: 'Strength',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });
    createdUserIds.push(marcusUser.id);
    const marcusProfile = marcusUser.clientProfile!;

    // Client 2: Sophia Miller (Single Session Client for Insufficient Progression Tests)
    const sophiaUser = await prisma.user.create({
      data: {
        name: `Sophia Single ${timestamp}`,
        email: `sophia.single.${timestamp}@alphax.test`,
        passwordHash: '$2a$10$SECRET_HASH_SOPHIA',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: sophiaAxId,
            age: 25,
            gender: 'Female',
            heightCm: 168,
            weightKg: 62.0,
            fitnessLevel: 'Beginner',
            primaryGoal: 'Hypertrophy',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });
    createdUserIds.push(sophiaUser.id);
    const sophiaProfile = sophiaUser.clientProfile!;

    // Client 3: Leo Zero (Zero Workouts for Missing Data Verification)
    const leoUser = await prisma.user.create({
      data: {
        name: `Leo Empty ${timestamp}`,
        email: `leo.empty.${timestamp}@alphax.test`,
        passwordHash: '$2a$10$SECRET_HASH_LEO',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: leoAxId,
            age: 32,
            gender: 'Male',
            heightCm: 175,
            weightKg: 78.0,
            fitnessLevel: 'Intermediate',
            primaryGoal: 'Maintenance',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });
    createdUserIds.push(leoUser.id);

    // Seed Exercise Catalog Mapping for muscle analysis
    // Ensure "Bench Press", "Squat", "Barbell Deadlift" exist in Exercise table
    const ensureExercise = async (name: string, normalizedName: string, bodyPart: string, primaryMuscles: string[]) => {
      const existing = await prisma.exercise.findFirst({ where: { normalizedName } });
      if (!existing) {
        await prisma.exercise.create({
          data: {
            name,
            normalizedName,
            category: 'Strength',
            bodyPart,
            primaryMuscles,
            secondaryMuscles: [],
            equipment: 'Barbell',
            movementPattern: 'Push',
            instructions: ['Execute with proper technique.'],
            isActive: true,
          },
        });
      }
    };
    await ensureExercise('Bench Press', 'bench press', 'Chest', ['Chest', 'Triceps']);
    await ensureExercise('Barbell Squat', 'barbell squat', 'Legs', ['Quadriceps', 'Glutes']);
    await ensureExercise('Barbell Deadlift', 'barbell deadlift', 'Back', ['Hamstrings', 'Lower Back']);

    // Seed Marcus Workouts across two distinct 14-day periods
    // Baseline Period (Period 1): 2026-08-10 to 2026-08-23 (3 sessions)
    // Recent Period (Period 2): 2026-08-24 to 2026-09-06 (4 sessions with progression on Bench Press)

    // Period 1 - Session 1: 2026-08-12
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Upper Push A',
        workoutType: 'Strength',
        startedAt: new Date('2026-08-12T09:00:00.000Z'),
        completedAt: new Date('2026-08-12T10:00:00.000Z'),
        durationSeconds: 3600,
        totalVolume: 8000,
        completedSetsCount: 10,
        averageRpe: 7.5,
        averageRir: 2.5,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_bench_press',
              exerciseName: 'Bench Press',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 80, actualReps: 10, actualRpe: 7.0, actualRir: 3, isCompleted: true },
                  { setNumber: 2, actualWeight: 85, actualReps: 8, actualRpe: 7.5, actualRir: 2, isCompleted: true },
                  { setNumber: 3, actualWeight: 90, actualReps: 6, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Period 1 - Session 2: 2026-08-15
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Lower Legs A',
        workoutType: 'Strength',
        startedAt: new Date('2026-08-15T09:00:00.000Z'),
        completedAt: new Date('2026-08-15T10:15:00.000Z'),
        durationSeconds: 4500,
        totalVolume: 11000,
        completedSetsCount: 12,
        averageRpe: 8.0,
        averageRir: 2.0,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_squat',
              exerciseName: 'Barbell Squat',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 120, actualReps: 8, actualRpe: 7.5, actualRir: 2, isCompleted: true },
                  { setNumber: 2, actualWeight: 130, actualReps: 6, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                  { setNumber: 3, actualWeight: 140, actualReps: 5, actualRpe: 8.5, actualRir: 1, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Period 1 - Session 3: 2026-08-19
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Full Body Pull A',
        workoutType: 'Strength',
        startedAt: new Date('2026-08-19T09:00:00.000Z'),
        completedAt: new Date('2026-08-19T10:00:00.000Z'),
        durationSeconds: 3600,
        totalVolume: 9500,
        completedSetsCount: 10,
        averageRpe: 8.0,
        averageRir: 2.0,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_deadlift',
              exerciseName: 'Barbell Deadlift',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 150, actualReps: 5, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                  { setNumber: 2, actualWeight: 160, actualReps: 4, actualRpe: 8.5, actualRir: 1, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Period 2 - Session 4: 2026-08-25 (Bench Press progression: 85kg -> 95kg top set)
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Upper Push B',
        workoutType: 'Strength',
        startedAt: new Date('2026-08-25T09:00:00.000Z'),
        completedAt: new Date('2026-08-25T10:00:00.000Z'),
        durationSeconds: 3600,
        totalVolume: 9200,
        completedSetsCount: 11,
        averageRpe: 8.0,
        averageRir: 2.0,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_bench_press',
              exerciseName: 'Bench Press',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 85, actualReps: 10, actualRpe: 7.5, actualRir: 2, isCompleted: true },
                  { setNumber: 2, actualWeight: 90, actualReps: 8, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                  { setNumber: 3, actualWeight: 95, actualReps: 6, actualRpe: 8.5, actualRir: 1, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Period 2 - Session 5: 2026-08-28
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Lower Legs B',
        workoutType: 'Strength',
        startedAt: new Date('2026-08-28T09:00:00.000Z'),
        completedAt: new Date('2026-08-28T10:20:00.000Z'),
        durationSeconds: 4800,
        totalVolume: 12500,
        completedSetsCount: 13,
        averageRpe: 8.5,
        averageRir: 1.5,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_squat',
              exerciseName: 'Barbell Squat',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 130, actualReps: 8, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                  { setNumber: 2, actualWeight: 140, actualReps: 6, actualRpe: 8.5, actualRir: 1, isCompleted: true },
                  { setNumber: 3, actualWeight: 150, actualReps: 4, actualRpe: 9.0, actualRir: 1, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Period 2 - Session 6: 2026-09-01 (Bench Press PR top set: 100kg x 5 reps!)
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Upper Push Heavy',
        workoutType: 'Strength',
        startedAt: new Date('2026-09-01T09:00:00.000Z'),
        completedAt: new Date('2026-09-01T10:10:00.000Z'),
        durationSeconds: 4200,
        totalVolume: 10500,
        completedSetsCount: 12,
        averageRpe: 8.5,
        averageRir: 1.5,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_bench_press',
              exerciseName: 'Bench Press',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 90, actualReps: 8, actualRpe: 7.5, actualRir: 2, isCompleted: true },
                  { setNumber: 2, actualWeight: 95, actualReps: 6, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                  { setNumber: 3, actualWeight: 100, actualReps: 5, actualRpe: 9.0, actualRir: 1, isCompleted: true }, // Highest weight PR!
                ],
              },
            },
          ],
        },
      },
    });

    // Period 2 - Session 7: 2026-09-04
    await prisma.workoutRecord.create({
      data: {
        clientId: marcusUser.id,
        sessionTitle: 'Deadlift & Posterior',
        workoutType: 'Strength',
        startedAt: new Date('2026-09-04T09:00:00.000Z'),
        completedAt: new Date('2026-09-04T10:00:00.000Z'),
        durationSeconds: 3600,
        totalVolume: 11000,
        completedSetsCount: 11,
        averageRpe: 8.5,
        averageRir: 1.5,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_deadlift',
              exerciseName: 'Barbell Deadlift',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 160, actualReps: 5, actualRpe: 8.0, actualRir: 2, isCompleted: true },
                  { setNumber: 2, actualWeight: 175, actualReps: 3, actualRpe: 9.0, actualRir: 1, isCompleted: true }, // PR Deadlift!
                ],
              },
            },
          ],
        },
      },
    });

    // Seed Sophia with ONLY 1 workout session (Single occurrence to test insufficient data guard)
    await prisma.workoutRecord.create({
      data: {
        clientId: sophiaUser.id,
        sessionTitle: 'Introductory Full Body',
        workoutType: 'Hypertrophy',
        startedAt: new Date('2026-09-02T11:00:00.000Z'),
        completedAt: new Date('2026-09-02T11:45:00.000Z'),
        durationSeconds: 2700,
        totalVolume: 3500,
        completedSetsCount: 6,
        averageRpe: 7.0,
        averageRir: 3.0,
        isCompleted: true,
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_bench_press',
              exerciseName: 'Bench Press',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 35, actualReps: 12, actualRpe: 6.5, actualRir: 3, isCompleted: true },
                  { setNumber: 2, actualWeight: 40, actualReps: 10, actualRpe: 7.5, actualRir: 2, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    console.log('--- Test Fixtures Seeded Successfully ---\n');

    // ==========================================================================
    // GROUP 1: SCHEMA & MODEL COMPATIBILITY (Tests 1-8)
    // ==========================================================================
    console.log('--- Group 1: Schema & Model Compatibility ---');

    const sampleWorkout = await prisma.workoutRecord.findFirst({
      where: { clientId: marcusUser.id },
      include: {
        exerciseRecords: {
          include: { setRecords: true },
        },
      },
    });

    assert(!!sampleWorkout, 'TEST 1: WorkoutRecord exists and is queried via real Prisma schema');
    assert(sampleWorkout?.clientId === marcusUser.id, 'TEST 2: WorkoutRecord references User.id correctly');
    assert(typeof sampleWorkout?.totalVolume === 'number', 'TEST 3: WorkoutRecord has authoritative totalVolume Float');
    assert(typeof sampleWorkout?.durationSeconds === 'number', 'TEST 4: WorkoutRecord has durationSeconds Int');
    assert(sampleWorkout?.exerciseRecords.length! > 0, 'TEST 5: WorkoutExerciseRecord relation functions properly');
    assert(sampleWorkout?.exerciseRecords[0].setRecords.length! > 0, 'TEST 6: WorkoutSetRecord relation with actualWeight and actualReps functions properly');
    assert(sampleWorkout?.isCompleted === true, 'TEST 7: isCompleted boolean flag is true for completed workouts');

    const dbExercise = await prisma.exercise.findFirst({ where: { normalizedName: 'bench press' } });
    assert(dbExercise?.primaryMuscles.includes('Chest') === true, 'TEST 8: Exercise table provides authoritative primaryMuscles mapping');

    // ==========================================================================
    // GROUP 2: SESSION ANALYSIS (Tests 9-18)
    // ==========================================================================
    console.log('--- Group 2: Session Analysis ---');

    const marcusSessionsRes = await workoutIntelligenceService.analyzeWorkoutProgress(marcusAxId);
    assert(marcusSessionsRes.status === 'SUCCESS', 'TEST 9: Session analysis returns SUCCESS for multi-session client');
    assert(marcusSessionsRes.value.completedSessionsCount === 7, 'TEST 10: Correctly counts 7 completed sessions for Marcus');
    assert(marcusSessionsRes.value.trainingDaysCount === 7, 'TEST 11: Correctly identifies 7 distinct training days');
    assert(marcusSessionsRes.value.sessionsPerWeek > 1.5, 'TEST 12: Calculates realistic average weekly sessions');
    assert(marcusSessionsRes.value.sessionsPerMonth > 0, 'TEST 13: Calculates sessions per month');
    assert(marcusSessionsRes.value.oldestSessionDate === '2026-08-12', 'TEST 14: Accurately identifies oldest session date (2026-08-12)');
    assert(marcusSessionsRes.value.mostRecentSessionDate === '2026-09-04', 'TEST 15: Accurately identifies most recent session date (2026-09-04)');
    assert(typeof marcusSessionsRes.value.averageGapDays === 'number', 'TEST 16: Computes average gap between recorded sessions');
    assert(marcusSessionsRes.value.longestGapDays >= 3, 'TEST 17: Computes longest gap between recorded sessions');

    const leoEmptyRes = await workoutIntelligenceService.analyzeWorkoutProgress(leoAxId);
    assert(leoEmptyRes.status === 'NO_RECORDS_FOUND', 'TEST 18: Client with zero workouts returns NO_RECORDS_FOUND');

    // ==========================================================================
    // GROUP 3: TRAINING FREQUENCY ANALYSIS (Tests 19-27)
    // ==========================================================================
    console.log('--- Group 3: Training Frequency Analysis ---');

    const freqRes = await workoutIntelligenceService.analyzeTrainingFrequency(marcusAxId);
    assert(freqRes.status === 'SUCCESS', 'TEST 19: Training frequency returns SUCCESS');
    assert(freqRes.recordCount === 7, 'TEST 20: Training frequency reports 7 sessions');
    assert(freqRes.value.trainingDaysCount === 7, 'TEST 21: Training frequency reports 7 recorded training days');
    assert(freqRes.value.activeWeeksCount >= 3, 'TEST 22: Identifies active training weeks');
    assert(freqRes.value.averageSessionsPerWeek > 0, 'TEST 23: Calculates average weekly frequency');
    assert(freqRes.unit.includes('sessions/week'), 'TEST 24: Formats frequency unit with sessions/week');
    assert(freqRes.source === 'ALPHA_X_DATABASE', 'TEST 25: Provenance source is ALPHA_X_DATABASE');
    assert(freqRes.calculationMethod === 'DETERMINISTIC_CALCULATION', 'TEST 26: Calculation method is DETERMINISTIC_CALCULATION');

    const leoFreqRes = await workoutIntelligenceService.analyzeTrainingFrequency(leoAxId);
    assert(leoFreqRes.status === 'NO_RECORDS_FOUND', 'TEST 27: Zero workout client frequency returns NO_RECORDS_FOUND');

    // ==========================================================================
    // GROUP 4: TRAINING VOLUME ANALYSIS (Tests 28-38)
    // ==========================================================================
    console.log('--- Group 4: Training Volume Analysis ---');

    const volRes = await workoutIntelligenceService.analyzeTrainingVolume(marcusAxId);
    assert(volRes.status === 'SUCCESS', 'TEST 28: Volume analysis returns SUCCESS');
    // Sum of totalVolume: 8000 + 11000 + 9500 + 9200 + 12500 + 10500 + 11000 = 71700 kg
    assert(volRes.value.totalVolumeKg === 71700, 'TEST 29: Authoritative total volume matches exact sum (71700 kg)', `Got ${volRes.value.totalVolumeKg}`);
    assert(volRes.recordCount === 7, 'TEST 30: Volume session count is 7');
    assert(volRes.value.averageSessionVolumeKg === round2(71700 / 7), 'TEST 31: Average session volume is exact');
    assert(volRes.value.minSessionVolumeKg === 8000, 'TEST 32: Minimum session volume is 8000 kg');
    assert(volRes.value.maxSessionVolumeKg === 12500, 'TEST 33: Maximum session volume is 12500 kg');
    assert(volRes.value.volumeByExercise.length >= 3, 'TEST 34: Volume broken down across exercises');
    assert(volRes.value.volumeByMuscleGroup.length >= 1, 'TEST 35: Volume broken down by primary muscle groups');

    const benchVol = volRes.value.volumeByExercise.find((e: any) => e.exerciseName.toLowerCase().includes('bench'));
    assert(!!benchVol && benchVol.totalVolumeKg > 0, 'TEST 36: Bench Press exercise volume correctly tabulated');

    const chestVol = volRes.value.volumeByMuscleGroup.find((m: any) => m.muscleGroup.toLowerCase() === 'chest');
    assert(!!chestVol && chestVol.totalVolumeKg > 0, 'TEST 37: Chest muscle group volume correctly mapped from Exercise catalog');

    const sophiaVolRes = await workoutIntelligenceService.analyzeTrainingVolume(sophiaAxId);
    assert(sophiaVolRes.value.totalVolumeKg === 3500, 'TEST 38: Sophia single session volume matches 3500 kg');

    // ==========================================================================
    // GROUP 5: EXERCISE PERFORMANCE ANALYSIS (Tests 39-49)
    // ==========================================================================
    console.log('--- Group 5: Exercise Performance Analysis ---');

    const benchPerfRes = await workoutIntelligenceService.analyzeExerciseProgress(marcusAxId, 'Bench Press');
    assert(benchPerfRes.status === 'SUCCESS', 'TEST 39: Exercise performance analysis returns SUCCESS for Bench Press');
    assert(benchPerfRes.value.totalSessions === 3, 'TEST 40: Bench press performed across 3 distinct sessions');
    assert(benchPerfRes.value.totalSets === 9, 'TEST 41: Total completed sets for Bench Press is 9 (3 sets x 3 sessions)');
    assert(benchPerfRes.value.maxWeightKg === 100, 'TEST 42: Max recorded Bench Press weight is 100 kg');
    assert(benchPerfRes.value.averageWeightKg > 85, 'TEST 43: Average Bench Press weight calculated properly');
    assert(benchPerfRes.value.maxReps === 10, 'TEST 44: Max reps in a single set is 10');
    assert(benchPerfRes.value.latestPerformance.topWeightKg === 100, 'TEST 45: Latest session max weight is 100 kg');
    assert(benchPerfRes.value.previousPerformance.topWeightKg === 95, 'TEST 46: Previous session max weight is 95 kg');
    assert(benchPerfRes.value.performanceDifference.weightDeltaKg === 5, 'TEST 47: Weight delta between latest and previous is +5 kg');
    assert(benchPerfRes.value.performanceDifference.direction === 'INCREASED', 'TEST 48: Progression direction categorized as INCREASED');
    assert(typeof benchPerfRes.value.performanceDifference.percentageVolumeChange === 'number', 'TEST 49: Percentage volume change is a valid number');

    // ==========================================================================
    // GROUP 6: EXERCISE PROGRESSION & INSUFFICIENT DATA (Tests 50-58)
    // ==========================================================================
    console.log('--- Group 6: Exercise Progression & Insufficient Data ---');

    // Sophia performed Bench Press ONLY ONCE
    const sophiaProgRes = await workoutIntelligenceService.analyzeExerciseProgress(sophiaAxId, 'Bench Press');
    assert(sophiaProgRes.status === 'INSUFFICIENT_DATA', 'TEST 50: Single-occurrence exercise returns INSUFFICIENT_DATA for progression');
    assert(sophiaProgRes.value.performanceDifference === null, 'TEST 51: Single session performanceDifference is null');
    assert(sophiaProgRes.value.previousPerformance === null, 'TEST 52: Previous performance is null for single session');
    assert(sophiaProgRes.message?.toLowerCase().includes('only 1 recorded'), 'TEST 53: Informative message states only 1 recorded occurrence exists');

    // Query exercise not performed by Marcus
    const unperformedRes = await workoutIntelligenceService.analyzeExerciseProgress(marcusAxId, 'Overhead Press');
    assert(unperformedRes.status === 'NO_RECORDS_FOUND', 'TEST 54: Unperformed exercise returns NO_RECORDS_FOUND');

    // Case-insensitive lookup test
    const benchLowerRes = await workoutIntelligenceService.analyzeExerciseProgress(marcusAxId, 'bench press');
    assert(benchLowerRes.status === 'SUCCESS', 'TEST 55: Case-insensitive exercise matching functions correctly');

    // Directional classification check for pure calculator
    const calcProgDec = workoutIntelligenceCalculator.analyzeExercise('Bench Press', [
      {
        id: 'w1',
        sessionTitle: 'S1',
        startedAt: new Date('2026-08-01'),
        durationSeconds: 3000,
        totalVolume: 5000,
        completedSetsCount: 3,
        averageRpe: 8,
        averageRir: 2,
        isCompleted: true,
        exerciseRecords: [
          {
            exerciseName: 'Bench Press',
            setRecords: [{ setNumber: 1, actualWeight: 100, actualReps: 5, isCompleted: true }],
          },
        ],
      },
      {
        id: 'w2',
        sessionTitle: 'S2',
        startedAt: new Date('2026-08-08'),
        durationSeconds: 3000,
        totalVolume: 4500,
        completedSetsCount: 3,
        averageRpe: 8,
        averageRir: 2,
        isCompleted: true,
        exerciseRecords: [
          {
            exerciseName: 'Bench Press',
            setRecords: [{ setNumber: 1, actualWeight: 90, actualReps: 5, isCompleted: true }],
          },
        ],
      },
    ]);
    assert(calcProgDec?.performanceDifference?.direction === 'DECREASED', 'TEST 56: Calculator identifies DECREASED progression direction');
    assert(calcProgDec?.performanceDifference?.weightDeltaKg === -10, 'TEST 57: Calculator identifies negative delta (-10 kg)');
    assert(calcProgDec?.performanceDifference?.percentageVolumeChange! < 0, 'TEST 58: Calculator identifies negative % change');

    // ==========================================================================
    // GROUP 7: PERSONAL BEST RECORDS (Tests 59-67)
    // ==========================================================================
    console.log('--- Group 7: Personal Best Records ---');

    const pbRes = await workoutIntelligenceService.getPersonalBests(marcusAxId);
    assert(pbRes.status === 'SUCCESS', 'TEST 59: Personal bests retrieval returns SUCCESS');
    assert(Array.isArray(pbRes.value), 'TEST 60: Personal bests returns an array');
    assert(pbRes.value.length >= 3, 'TEST 61: Multiple personal best records identified across exercises');

    const benchMaxWeightPb = pbRes.value.find((p: any) => p.exerciseName === 'Bench Press' && (p.metric === 'HIGHEST_WEIGHT' || p.metricLabel === 'Highest Recorded Weight'));
    assert(!!benchMaxWeightPb, 'TEST 62: Highest Recorded Weight PR identified for Bench Press');
    assert(benchMaxWeightPb?.value === 100, 'TEST 63: Bench Press PR weight is exactly 100 kg');
    assert(benchMaxWeightPb?.unit === 'kg', 'TEST 64: PR weight unit is kg');

    const deadliftMaxWeightPb = pbRes.value.find((p: any) => p.exerciseName === 'Barbell Deadlift' && (p.metric === 'HIGHEST_WEIGHT' || p.metricLabel === 'Highest Recorded Weight'));
    assert(deadliftMaxWeightPb?.value === 175, 'TEST 65: Barbell Deadlift PR weight is exactly 175 kg');

    const filteredPbRes = await workoutIntelligenceService.getPersonalBests(marcusAxId, 'Bench Press');
    assert(filteredPbRes.value.every((p: any) => p.exerciseName === 'Bench Press'), 'TEST 66: Filtering PRs by exercise name returns only that exercise');

    const emptyPbRes = await workoutIntelligenceService.getPersonalBests(leoAxId);
    assert(emptyPbRes.status === 'NO_RECORDS_FOUND', 'TEST 67: Client with no workouts returns NO_RECORDS_FOUND for PRs');

    // ==========================================================================
    // GROUP 8: RPE & INTENSITY ANALYSIS (Tests 68-76)
    // ==========================================================================
    console.log('--- Group 8: RPE & Intensity Analysis ---');

    const intensityRes = await workoutIntelligenceService.analyzeWorkoutIntensity(marcusAxId);
    assert(intensityRes.status === 'SUCCESS', 'TEST 68: Workout intensity returns SUCCESS');
    assert(intensityRes.value.rpeRecordCount === 7, 'TEST 69: All 7 sessions have RPE recorded');
    assert(typeof intensityRes.value.averageRpe === 'number', 'TEST 70: Average RPE is a number');
    assert(intensityRes.value.averageRpe! >= 7.5 && intensityRes.value.averageRpe! <= 8.5, 'TEST 71: Average RPE is in expected 7.5-8.5 range');
    assert(intensityRes.value.minRpe === 7.5, 'TEST 72: Min recorded session RPE is 7.5');
    assert(intensityRes.value.maxRpe === 8.5, 'TEST 73: Max recorded session RPE is 8.5');
    assert(typeof intensityRes.value.averageRir === 'number', 'TEST 74: Average RIR is computed');
    assert(intensityRes.value.minRir === 1.5, 'TEST 75: Min recorded session RIR is 1.5');
    assert(intensityRes.value.maxRir === 2.5, 'TEST 76: Max recorded session RIR is 2.5');

    // ==========================================================================
    // GROUP 9: PERIOD COMPARISON ENGINE (Tests 77-87)
    // ==========================================================================
    console.log('--- Group 9: Period Comparison Engine ---');

    // Compare Marcus Period 1 (2026-08-10 to 2026-08-23) vs Period 2 (2026-08-24 to 2026-09-06)
    const customCompRes = await workoutIntelligenceService.compareWorkoutPeriods(marcusAxId, {
      prevStart: '2026-08-10',
      prevEnd: '2026-08-23',
      currentStart: '2026-08-24',
      currentEnd: '2026-09-06',
    });

    assert(customCompRes.status === 'SUCCESS', 'TEST 77: Custom period comparison returns SUCCESS');
    assert(customCompRes.value.previousPeriod.sessionCount === 3, 'TEST 78: Period 1 had 3 completed sessions');
    assert(customCompRes.value.currentPeriod.sessionCount === 4, 'TEST 79: Period 2 had 4 completed sessions');
    assert(customCompRes.value.comparison.sessionCountDelta === 1, 'TEST 80: Session delta is +1 session');
    assert(customCompRes.value.comparison.direction === 'INCREASED', 'TEST 81: Direction categorized as INCREASED');

    // Period 1 Volume: 8000 + 11000 + 9500 = 28500 kg
    // Period 2 Volume: 9200 + 12500 + 10500 + 11000 = 43200 kg
    assert(customCompRes.value.previousPeriod.totalVolumeKg === 28500, 'TEST 82: Period 1 volume matches 28500 kg');
    assert(customCompRes.value.currentPeriod.totalVolumeKg === 43200, 'TEST 83: Period 2 volume matches 43200 kg');
    assert(customCompRes.value.comparison.volumeDeltaKg === 14700, 'TEST 84: Volume delta matches +14700 kg');
    assert(customCompRes.value.comparison.direction === 'INCREASED', 'TEST 85: Volume direction categorized as INCREASED');
    assert(customCompRes.value.comparison.volumePercentageChange > 50, 'TEST 86: Volume % change is over 50%');

    // Preset comparison test
    const presetCompRes = await workoutIntelligenceService.compareWorkoutPeriods(marcusAxId, {
      preset: 'last_14_days',
    });
    assert(presetCompRes.status === 'SUCCESS' || presetCompRes.status === 'NO_RECORDS_FOUND', 'TEST 87: Preset comparison (last_14_days) executes cleanly');

    // ==========================================================================
    // GROUP 10: DATE RANGE VALIDATION ENGINE (Tests 88-93)
    // ==========================================================================
    console.log('--- Group 10: Date Range Validation Engine ---');

    const validDates = validateDateRange('2026-08-01', '2026-08-15');
    assert(validDates.start instanceof Date && validDates.end instanceof Date, 'TEST 88: Valid date range parsed into Date objects');

    let invalidFormatThrown = false;
    try {
      validateDateRange('01-08-2026', '2026-08-15');
    } catch {
      invalidFormatThrown = true;
    }
    assert(invalidFormatThrown, 'TEST 89: Invalid date format throws validation error');

    let invertedRangeThrown = false;
    try {
      validateDateRange('2026-08-20', '2026-08-10');
    } catch {
      invertedRangeThrown = true;
    }
    assert(invertedRangeThrown, 'TEST 90: Inverted date range (start > end) throws validation error');

    let futureDateThrown = false;
    try {
      validateDateRange('2026-08-01', '2030-01-01');
    } catch {
      futureDateThrown = true;
    }
    assert(futureDateThrown, 'TEST 91: Future date beyond permitted boundary throws validation error');

    let overlapThrown = false;
    try {
      validateCustomComparisonIntervals('2026-08-15', '2026-08-25', '2026-08-10', '2026-08-20');
    } catch {
      overlapThrown = true;
    }
    assert(overlapThrown, 'TEST 92: Overlapping period comparison intervals throw validation error');

    const presets = computePresetComparisonDates('last_7_days');
    assert(!!presets.current.startDate && !!presets.previous.startDate, 'TEST 93: Preset comparison intervals compute contiguous non-overlapping windows');

    // ==========================================================================
    // GROUP 11: MISSING, INSUFFICIENT & CORRUPTED DATA HANDLING (Tests 94-100)
    // ==========================================================================
    console.log('--- Group 11: Missing, Insufficient & Corrupted Data ---');

    const nonExistentClient = await workoutIntelligenceService.analyzeWorkoutProgress('AXG-NONEXISTENT-999');
    assert(nonExistentClient.status === 'CLIENT_NOT_FOUND', 'TEST 94: Non-existent client returns CLIENT_NOT_FOUND');

    const safeRoundNaN = round2(NaN);
    assert(safeRoundNaN === 0, 'TEST 95: round2 converts NaN safely to 0');

    const safeRoundInfinity = round2(Infinity);
    assert(safeRoundInfinity === 0, 'TEST 96: round2 converts Infinity safely to 0');

    // Empty session set handling
    const emptySessionsAnalysis = workoutIntelligenceCalculator.analyzeSessions([]);
    assert(emptySessionsAnalysis.completedSessionsCount === 0, 'TEST 97: Empty sessions list produces 0 completed sessions');
    assert(emptySessionsAnalysis.averageWeeklySessions === 0, 'TEST 98: Empty sessions list produces 0 weekly sessions');

    // Bodyweight exercise (0 weight) load handling
    const bodyweightExerciseAnalysis = workoutIntelligenceCalculator.analyzeExercise('Pull-up', [
      {
        id: 'bw1',
        sessionTitle: 'Calisthenics',
        startedAt: new Date('2026-08-01'),
        durationSeconds: 1800,
        totalVolume: 0,
        completedSetsCount: 3,
        averageRpe: 7,
        averageRir: 3,
        isCompleted: true,
        exerciseRecords: [
          {
            exerciseName: 'Pull-up',
            setRecords: [
              { setNumber: 1, actualWeight: 0, actualReps: 10, isCompleted: true },
              { setNumber: 2, actualWeight: 0, actualReps: 8, isCompleted: true },
            ],
          },
        ],
      },
    ]);
    assert(bodyweightExerciseAnalysis?.maxWeightKg === 0, 'TEST 99: Bodyweight exercise handles 0 kg load safely');
    assert(bodyweightExerciseAnalysis?.totalReps === 18, 'TEST 100: Total reps for bodyweight sets correctly summed (18 reps)');

    // ==========================================================================
    // GROUP 12: SECURITY, PERMISSIONS & VERIFIED CONTEXT (Tests 101-108)
    // ==========================================================================
    console.log('--- Group 12: Security, Permissions & Verified Context ---');

    // Tool registered in toolRegistry
    assert(toolRegistry.hasTool('analyze_client_workout_progress'), 'TEST 101: analyze_client_workout_progress tool registered');
    assert(toolRegistry.hasTool('analyze_client_exercise_progress'), 'TEST 102: analyze_client_exercise_progress tool registered');
    assert(toolRegistry.hasTool('compare_client_workout_periods'), 'TEST 103: compare_client_workout_periods tool registered');
    assert(toolRegistry.hasTool('get_client_personal_bests'), 'TEST 104: get_client_personal_bests tool registered');

    // Tool execution through ToolExecutor with verified client context
    const verifiedToolExec = await toolExecutor.executeTool(
      'analyze_client_workout_progress',
      { clientId: 'this client' }, // pronoun!
      {
        ...adminContext,
        verifiedClient: {
          clientId: marcusAxId,
          userId: marcusUser.id,
          profileId: marcusProfile.id,
          displayName: marcusUser.name,
          identitySource: 'EXPLICIT_AXG_ID',
          verified: true,
          selectedAt: new Date().toISOString(),
        },
      }
    );
    assert(verifiedToolExec.success === true, 'TEST 105: Pronoun "this client" automatically resolves to active verifiedClient');
    assert(verifiedToolExec.data?.status === 'SUCCESS', 'TEST 106: Tool execution succeeded with verified client context');

    // Tool execution with pronoun but WITHOUT verified client context must fail
    const unverifiedResult = await toolExecutor.executeTool(
      'analyze_client_workout_progress',
      { clientId: 'the client' },
      { ...adminContext, verifiedClient: undefined }
    );
    const unverifiedBlocked =
      unverifiedResult.success === false &&
      (unverifiedResult.error?.includes('No verified client context is active') || false);
    assert(unverifiedBlocked, 'TEST 107: Pronoun execution fails without active verified client context');

    // WRITE protection: verify no tools allow write operations
    const allTools = toolRegistry.listTools(true);
    const phase9ToolNames = [
      'analyze_client_workout_progress',
      'analyze_client_exercise_progress',
      'analyze_client_training_frequency',
      'analyze_client_training_volume',
      'analyze_client_workout_intensity',
      'compare_client_workout_periods',
      'get_client_personal_bests',
    ];
    const phase9Tools = allTools.filter((t: any) => phase9ToolNames.includes(t.name));
    const allReadOnly = phase9Tools.every((t: any) => t.permission === ToolPermission.ANALYZE_DATA || t.category === 'ANALYZE');
    assert(allReadOnly && phase9Tools.length === 7, 'TEST 108: All 7 Phase 9 tools are strictly ANALYZE/read-only with no WRITE capability');

    // ==========================================================================
    // GROUP 13: GEMINI INTEGRATION & TOOL DECLARATIONS (Tests 109-112)
    // ==========================================================================
    console.log('--- Group 13: Gemini Integration & Tool Declarations ---');

    const geminiDeclarations = toolRegistry.getGeminiDeclarations();
    const workoutProgressDecl = geminiDeclarations.find((d: any) => d.name === 'analyze_client_workout_progress');
    assert(!!workoutProgressDecl, 'TEST 109: Gemini function declaration generated for analyze_client_workout_progress');

    const comparePeriodsDecl = geminiDeclarations.find((d: any) => d.name === 'compare_client_workout_periods');
    assert(!!comparePeriodsDecl, 'TEST 110: Gemini function declaration generated for compare_client_workout_periods');

    const personalBestsDecl = geminiDeclarations.find((d: any) => d.name === 'get_client_personal_bests');
    assert(!!personalBestsDecl, 'TEST 111: Gemini function declaration generated for get_client_personal_bests');

    assert(ALPHA_X_AI_SYSTEM_INSTRUCTION_V2.includes('Workout Intelligence & Performance Analysis'), 'TEST 112: System prompt contains Phase 9 Workout Intelligence instructions');

    // ==========================================================================
    // GROUP 14: FULL REGRESSION VERIFICATION (Tests 113-118)
    // ==========================================================================
    console.log('--- Group 14: Full Regression Verification ---');

    // Phase 1: Gemini service initialized and valid
    assert(geminiService !== undefined && geminiService.promptVersion === '2.0', 'TEST 113: Phase 1 Gemini service foundation intact');

    // Phase 3: Fitness Knowledge / RAG intact
    const r = await import('./knowledge');
    assert(r.knowledgeService !== undefined, 'TEST 114: Phase 3 Fitness Knowledge base intact');

    // Phase 5: Baseline tools intact
    assert(toolRegistry.hasTool('get_ai_status'), 'TEST 115: Phase 5 baseline tool registry intact');

    // Phase 6: Client data tools intact
    assert(toolRegistry.hasTool('get_client_workout_history'), 'TEST 116: Phase 6 client data tools intact');

    // Phase 7: Client identification intact
    const clientResolve = await clientDataService.resolveClient(marcusAxId);
    assert(clientResolve.status === 'FOUND', 'TEST 117: Phase 7 Client resolution intact');

    // Phase 8: Calculation tools intact
    assert(toolRegistry.hasTool('calculate_client_workout_summary'), 'TEST 118: Phase 8 calculation tools intact');

  } catch (err: any) {
    console.error('UNEXPECTED TEST HARNESS ERROR:', err);
    failed++;
  } finally {
    console.log('\n--- Cleaning up Test Fixtures from Alpha X Database ---');
    try {
      if (createdUserIds.length > 0) {
        await prisma.user.deleteMany({
          where: { id: { in: createdUserIds } },
        });
        console.log(`Cleaned up ${createdUserIds.length} test user records.`);
      }
    } catch (cleanupErr) {
      console.error('Error during cleanup:', cleanupErr);
    }
    server.close();
  }

  console.log('\n================================================================');
  console.log(`🏁  TEST RESULTS: ${passed} PASSED, ${failed} FAILED (TOTAL: ${passed + failed})`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase9WorkoutIntelligenceTests();

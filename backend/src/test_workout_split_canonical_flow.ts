import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';

function assert(condition: boolean, message: string) {
  if (!condition) {
    console.error(`❌ ASSERTION FAILED: ${message}`);
    throw new Error(message);
  } else {
    console.log(`  ✓ ${message}`);
  }
}

async function runCanonicalSplitRegressionSuite() {
  console.log('================================================================');
  console.log('ALPHA X GYM — WORKOUT SPLIT & DAY-WISE SESSION REGRESSION SUITE');
  console.log('================================================================\n');

  const clientAlex = 'client_alex_ppl_test';
  const clientJordan = 'client_jordan_upper_lower_test';
  const adminId = 'admin_head_coach';

  // ---------------------------------------------------------------------------
  // TEST 1: Admin assigns a 6-day PPL split; each day is an isolated session
  // ---------------------------------------------------------------------------
  console.log('TEST 1: Admin assigns a 6-day PPL split (Monday-Saturday)');
  const pplSplitData = {
    title: 'Alpha 6-Day PPL Hypertrophy Split',
    description: 'High frequency Push/Pull/Legs cycle',
    clientIds: [clientAlex],
    days: [
      {
        dayOfWeek: 'Monday',
        name: 'Push Day A',
        targetMuscleGroup: 'Chest, Shoulders, Triceps',
        workoutType: 'Strength',
        estimatedDurationMinutes: 50,
        exercises: [
          { exerciseId: 'ex_bench', name: 'Barbell Flat Bench Press', sets: 3, reps: '8-10', targetWeight: 80, restSeconds: 90 },
          { exerciseId: 'ex_ohp', name: 'Overhead Press', sets: 3, reps: '8-10', targetWeight: 45, restSeconds: 90 },
          { exerciseId: 'ex_incline_db', name: 'Incline Dumbbell Press', sets: 3, reps: '10-12', targetWeight: 26, restSeconds: 60 },
          { exerciseId: 'ex_lateral_raise', name: 'Dumbbell Lateral Raise', sets: 3, reps: '12-15', targetWeight: 10, restSeconds: 60 },
          { exerciseId: 'ex_tricep_pushdown', name: 'Cable Tricep Pushdown', sets: 3, reps: '10-12', targetWeight: 25, restSeconds: 60 },
        ],
      },
      {
        dayOfWeek: 'Tuesday',
        name: 'Pull Day A',
        targetMuscleGroup: 'Back, Biceps, Rear Delts',
        workoutType: 'Hypertrophy',
        estimatedDurationMinutes: 50,
        exercises: [
          { exerciseId: 'ex_deadlift', name: 'Barbell Deadlift', sets: 3, reps: '6-8', targetWeight: 110, restSeconds: 120 },
          { exerciseId: 'ex_lat_pull', name: 'Lat Pulldown', sets: 3, reps: '8-12', targetWeight: 55, restSeconds: 90 },
          { exerciseId: 'ex_cable_row', name: 'Seated Cable Row', sets: 3, reps: '10-12', targetWeight: 50, restSeconds: 90 },
          { exerciseId: 'ex_face_pull', name: 'Face Pull', sets: 3, reps: '12-15', targetWeight: 18, restSeconds: 60 },
          { exerciseId: 'ex_bicep_curl', name: 'Barbell Bicep Curl', sets: 3, reps: '8-10', targetWeight: 25, restSeconds: 60 },
        ],
      },
      {
        dayOfWeek: 'Wednesday',
        name: 'Legs Day A',
        targetMuscleGroup: 'Quads, Hamstrings, Calves',
        workoutType: 'Strength',
        estimatedDurationMinutes: 55,
        exercises: [
          { exerciseId: 'ex_squat', name: 'Barbell Back Squat', sets: 3, reps: '6-8', targetWeight: 95, restSeconds: 120 },
          { exerciseId: 'ex_rdl', name: 'Romanian Deadlift', sets: 3, reps: '8-10', targetWeight: 75, restSeconds: 90 },
          { exerciseId: 'ex_leg_press', name: 'Leg Press', sets: 3, reps: '10-12', targetWeight: 160, restSeconds: 90 },
          { exerciseId: 'ex_leg_curl', name: 'Hamstring Curl', sets: 3, reps: '10-12', targetWeight: 40, restSeconds: 60 },
          { exerciseId: 'ex_calf_raise', name: 'Standing Calf Raise', sets: 3, reps: '15-20', targetWeight: 50, restSeconds: 45 },
        ],
      },
      {
        dayOfWeek: 'Thursday',
        name: 'Push Day B',
        targetMuscleGroup: 'Upper Chest, Delts, Triceps',
        workoutType: 'Hypertrophy',
        estimatedDurationMinutes: 50,
        exercises: [
          { exerciseId: 'ex_incline_barbell', name: 'Incline Barbell Press', sets: 3, reps: '8-10', targetWeight: 65, restSeconds: 90 },
          { exerciseId: 'ex_flat_db', name: 'Flat Dumbbell Press', sets: 3, reps: '8-12', targetWeight: 28, restSeconds: 90 },
          { exerciseId: 'ex_cable_lateral', name: 'Cable Lateral Raise', sets: 3, reps: '12-15', targetWeight: 8, restSeconds: 60 },
          { exerciseId: 'ex_overhead_tricep', name: 'Overhead Tricep Extension', sets: 3, reps: '10-12', targetWeight: 20, restSeconds: 60 },
        ],
      },
      {
        dayOfWeek: 'Friday',
        name: 'Pull Day B',
        targetMuscleGroup: 'Upper Back, Lats, Biceps',
        workoutType: 'Hypertrophy',
        estimatedDurationMinutes: 50,
        exercises: [
          { exerciseId: 'ex_chest_row', name: 'Chest-Supported Row', sets: 3, reps: '8-10', targetWeight: 45, restSeconds: 90 },
          { exerciseId: 'ex_pullup', name: 'Neutral Grip Pull-Up', sets: 3, reps: '6-8', targetWeight: 0, restSeconds: 90 },
          { exerciseId: 'ex_hammer_curl', name: 'Hammer Curl', sets: 3, reps: '10-12', targetWeight: 14, restSeconds: 60 },
          { exerciseId: 'ex_incline_curl', name: 'Incline Dumbbell Curl', sets: 3, reps: '10-12', targetWeight: 12, restSeconds: 60 },
        ],
      },
      {
        dayOfWeek: 'Saturday',
        name: 'Legs Day B',
        targetMuscleGroup: 'Glutes, Hamstrings, Quads',
        workoutType: 'Hypertrophy',
        estimatedDurationMinutes: 50,
        exercises: [
          { exerciseId: 'ex_hip_thrust', name: 'Barbell Hip Thrust', sets: 3, reps: '8-10', targetWeight: 100, restSeconds: 90 },
          { exerciseId: 'ex_split_squat', name: 'Bulgarian Split Squat', sets: 3, reps: '8-10', targetWeight: 16, restSeconds: 90 },
          { exerciseId: 'ex_lying_leg_curl', name: 'Lying Leg Curl', sets: 3, reps: '10-12', targetWeight: 35, restSeconds: 60 },
          { exerciseId: 'ex_hanging_knee', name: 'Hanging Knee Raise', sets: 3, reps: '12-15', targetWeight: 0, restSeconds: 45 },
        ],
      },
    ],
  };

  const createdSplit = await workoutService.createWorkoutSplit(pplSplitData, adminId);
  assert(createdSplit.days.length === 7, 'Created split has 7 canonical days including Sunday Rest Day');
  const sunday = createdSplit.days.find(d => d.dayOfWeek === 'Sunday');
  assert(sunday !== undefined && sunday.isRestDay === true, 'Sunday is accurately designated as Rest Day');
  const monday = createdSplit.days.find(d => d.dayOfWeek === 'Monday');
  assert(monday?.exercises.length === 5, 'Monday Push Day has exactly 5 exercises, not 27 or 30');

  // ---------------------------------------------------------------------------
  // TEST 2: Admin preview and client workout structure match perfectly
  // ---------------------------------------------------------------------------
  console.log('\nTEST 2: Admin preview and client split structure parity');
  const clientSplit = await workoutService.getClientWorkoutSplit(clientAlex);
  assert(clientSplit !== null, 'Client split retrieved successfully');
  assert(clientSplit!.days.length === 7, 'Client split contains 7 structured days');
  assert(clientSplit!.days[0].dayOfWeek === 'Monday' && clientSplit!.days[0].exercises.length === 5, 'Client Monday has 5 exercises');
  assert(clientSplit!.days[1].dayOfWeek === 'Tuesday' && clientSplit!.days[1].exercises.length === 5, 'Client Tuesday has 5 exercises');
  assert(clientSplit!.days[2].dayOfWeek === 'Wednesday' && clientSplit!.days[2].exercises.length === 5, 'Client Wednesday has 5 exercises');
  assert(clientSplit!.days[3].dayOfWeek === 'Thursday' && clientSplit!.days[3].exercises.length === 4, 'Client Thursday has 4 exercises');
  assert(clientSplit!.days[4].dayOfWeek === 'Friday' && clientSplit!.days[4].exercises.length === 4, 'Client Friday has 4 exercises');
  assert(clientSplit!.days[5].dayOfWeek === 'Saturday' && clientSplit!.days[5].exercises.length === 4, 'Client Saturday has 4 exercises');
  assert(clientSplit!.days[6].dayOfWeek === 'Sunday' && clientSplit!.days[6].isRestDay === true, 'Client Sunday is Rest Day');

  // ---------------------------------------------------------------------------
  // TEST 3: Editing Tuesday does NOT alter or merge Monday or Wednesday
  // ---------------------------------------------------------------------------
  console.log('\nTEST 3: Isolated Day-Wise Editing');
  const tuesdayDayId = createdSplit.days.find(d => d.dayOfWeek === 'Tuesday')?.id || '';
  const updatedTuesday = await workoutService.updateWorkoutSplitDay(createdSplit.id, tuesdayDayId, {
    name: 'Pull Day A (Power Back Edition)',
    targetMuscleGroup: 'Back, Traps & Biceps',
    exercises: [
      { exerciseId: 'ex_weighted_pullup', name: 'Weighted Pull-Up', sets: 4, reps: '6-8', targetWeight: 10, restSeconds: 120 },
      { exerciseId: 'ex_chest_supported_tbar', name: 'Chest-Supported T-Bar Row', sets: 4, reps: '8-10', targetWeight: 45, restSeconds: 90 },
      { exerciseId: 'ex_cable_pullover', name: 'Straight-Arm Cable Pullover', sets: 3, reps: '12-15', targetWeight: 22, restSeconds: 60 },
      { exerciseId: 'ex_incline_hammer', name: 'Incline Dumbbell Hammer Curl', sets: 3, reps: '10-12', targetWeight: 14, restSeconds: 60 },
    ],
  });

  assert(updatedTuesday !== null, 'Tuesday was updated successfully');
  assert(updatedTuesday!.exercises.length === 4, 'Tuesday now has exactly 4 updated exercises');
  assert(updatedTuesday!.exercises[0].exerciseName === 'Weighted Pull-Up', 'Tuesday primary exercise updated to Weighted Pull-Up');

  // Verify Monday and Wednesday remained completely untouched!
  const reloadedSplit = await workoutService.getClientWorkoutSplit(clientAlex);
  const reloadedMon = reloadedSplit!.days.find(d => d.dayOfWeek === 'Monday');
  const reloadedTue = reloadedSplit!.days.find(d => d.dayOfWeek === 'Tuesday');
  const reloadedWed = reloadedSplit!.days.find(d => d.dayOfWeek === 'Wednesday');

  assert(reloadedMon?.exercises.length === 5, 'Monday still has exactly 5 exercises (unmodified)');
  assert(reloadedMon?.exercises[0].exerciseName === 'Barbell Flat Bench Press', 'Monday still starts with Barbell Flat Bench Press');
  assert(reloadedTue?.exercises.length === 4, 'Tuesday reflects updated 4 exercises');
  assert(reloadedWed?.exercises.length === 5, 'Wednesday still has exactly 5 exercises (unmodified)');

  // ---------------------------------------------------------------------------
  // TEST 4: Progression Rule: Incomplete workout stays required, subsequent locked
  // ---------------------------------------------------------------------------
  console.log('\nTEST 4: Workout progression and session locking enforcement');
  const authorizedMonday = await workoutRepository.getClientAuthorizedSessions(clientAlex, 'Monday');
  assert(authorizedMonday.recommended !== null, 'Monday workout is recommended and available');
  assert(authorizedMonday.recommended?.title.includes('Push') ?? false, 'Monday recommended is Push Day');

  // On Tuesday before completing Monday:
  const authorizedTuesdayUnfinished = await workoutRepository.getClientAuthorizedSessions(clientAlex, 'Tuesday');
  assert(authorizedTuesdayUnfinished.recommended !== null, 'Eligible session is present');
  assert(authorizedTuesdayUnfinished.recommended?.title.includes('Push Day A') ?? false, 'Monday Push Day remains required/recommended because it was not completed!');
  const tueSessionInList = authorizedTuesdayUnfinished.available.find(s => s.title.includes('Pull'));
  assert(tueSessionInList?.status === 'PREVIOUS_SESSION_REQUIRED', 'Tuesday Pull Day is locked with status PREVIOUS_SESSION_REQUIRED');

  // ---------------------------------------------------------------------------
  // TEST 5: Completing Monday locks Monday and unlocks Tuesday
  // ---------------------------------------------------------------------------
  console.log('\nTEST 5: Workout completion & next-day progression');
  const mondaySessionId = authorizedMonday.recommended!.id;
  await workoutService.recordWorkout(clientAlex, {
    sessionId: mondaySessionId,
    sessionTitle: authorizedMonday.recommended!.title,
    workoutType: authorizedMonday.recommended!.workoutType,
    targetMuscleGroup: authorizedMonday.recommended!.targetMuscleGroup,
    scheduledDate: 'Monday',
    durationSeconds: 2700,
    totalVolume: 8400,
    completedSets: 15,
    totalSets: 15,
    isCompleted: true,
    isLocked: true,
    exerciseRecords: (authorizedMonday.recommended!.exercises || []).map(e => ({
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      sets: (e.sets || []).map(s => ({ setNumber: s.setNumber, actualWeight: s.targetWeight ?? 0, actualReps: 10, isCompleted: true })),
    })),
  });

  // Now on Tuesday after Monday completed:
  const authorizedTuesdayFinished = await workoutRepository.getClientAuthorizedSessions(clientAlex, 'Tuesday');
  assert(authorizedTuesdayFinished.recommended !== null, 'Tuesday has recommended workout');
  assert(authorizedTuesdayFinished.recommended?.title.includes('Pull Day A') ?? false, 'Tuesday Pull Day is now successfully unlocked and recommended!');
  assert(authorizedTuesdayFinished.recommended?.status !== 'PREVIOUS_SESSION_REQUIRED', 'Tuesday status is active (unlocked)');

  // ---------------------------------------------------------------------------
  // TEST 6: Rest Day state handling (Sunday)
  // ---------------------------------------------------------------------------
  console.log('\nTEST 6: Rest Day state validation (Sunday)');
  const authorizedSunday = await workoutRepository.getClientAuthorizedSessions(clientAlex, 'Sunday');
  assert(authorizedSunday.recommended === null, 'Sunday returns recommended: null (Rest Day, no fallback to Monday!)');
  const sundayWorkouts = authorizedSunday.available.filter(s => (s.recurringSchedule || '').toLowerCase().includes('sunday'));
  assert(sundayWorkouts.length === 0, 'No workouts scheduled for Sunday');

  // ---------------------------------------------------------------------------
  // TEST 7: Client Isolation: Jordan on Upper/Lower split is isolated from Alex on PPL
  // ---------------------------------------------------------------------------
  console.log('\nTEST 7: Multi-Client Split Isolation');
  const upperLowerSplitData = {
    title: 'Jordan 4-Day Upper Lower Split',
    description: '4-day strength progression',
    clientIds: [clientJordan],
    days: [
      {
        dayOfWeek: 'Monday',
        name: 'Upper Strength',
        targetMuscleGroup: 'Upper Body',
        workoutType: 'Strength',
        estimatedDurationMinutes: 45,
        exercises: [
          { exerciseId: 'ex_incline_smith', name: 'Incline Smith Press', sets: 4, reps: '8-10', targetWeight: 70, restSeconds: 90 },
          { exerciseId: 'ex_lat_pull', name: 'Wide Grip Lat Pulldown', sets: 4, reps: '8-10', targetWeight: 60, restSeconds: 90 },
        ],
      },
      {
        dayOfWeek: 'Tuesday',
        name: 'Lower Strength',
        targetMuscleGroup: 'Lower Body',
        workoutType: 'Strength',
        estimatedDurationMinutes: 45,
        exercises: [
          { exerciseId: 'ex_squat', name: 'Front Squat', sets: 4, reps: '6-8', targetWeight: 70, restSeconds: 120 },
        ],
      },
    ],
  };

  await workoutService.createWorkoutSplit(upperLowerSplitData, adminId);
  const jordanSplit = await workoutService.getClientWorkoutSplit(clientJordan);
  const alexSplit = await workoutService.getClientWorkoutSplit(clientAlex);

  assert(jordanSplit?.title === 'Jordan 4-Day Upper Lower Split', 'Jordan has Upper Lower split');
  assert(alexSplit?.title === 'Alpha 6-Day PPL Hypertrophy Split', 'Alex retains PPL split');
  assert(jordanSplit?.days[0].exercises.length === 2, 'Jordan Monday has 2 exercises');
  assert(alexSplit?.days[0].exercises.length === 5, 'Alex Monday has 5 exercises');

  console.log('\n================================================================');
  console.log('✅ ALL 12 CANONICAL REGRESSION TESTS PASSED SUCCESSFULLY!');
  console.log('================================================================');
}

runCanonicalSplitRegressionSuite().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});

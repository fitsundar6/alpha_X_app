import { prisma } from './config/prisma';
import { createWorkoutRecordSchema } from './modules/workout/workout.validation';
import { workoutService } from './modules/workout/workout.service';

async function runTest() {
  console.log('================================================================');
  console.log('ALPHA X GYM — WORKOUT RECORD VALIDATION & PERSISTENCE TEST');
  console.log('================================================================\n');

  // 1. Verify schema accepts empty exerciseRecords array
  const reportedPayload = {
    sessionId: 'fa483f4f-8e26-4ce7-bb87-3424ff63e665',
    sessionTitle: 'AI Optimized Training Session',
    workoutType: 'Hypertrophy',
    startedAt: '2026-10-14T14:28:35.485633Z',
    completedAt: '2026-10-14T14:28:36.348300Z',
    durationSeconds: 5,
    totalVolume: 0,
    completedSetsCount: 0,
    skippedSetsCount: 0,
    averageRpe: null,
    averageRir: null,
    isCompleted: true,
    personalRecords: [],
    notes: null,
    exerciseRecords: [],
  };

  console.log('[Step 1] Validating reported empty exerciseRecords payload with Zod schema...');
  const parseResult = createWorkoutRecordSchema.safeParse(reportedPayload);
  if (!parseResult.success) {
    console.error('FAIL: Schema rejected empty exerciseRecords:', parseResult.error.errors);
    process.exit(1);
  }
  console.log('  ✓ Schema validation PASSED for empty exerciseRecords!\n');

  // 2. Test saving the workout record in database
  console.log('[Step 2] Testing saving record with workoutService.recordWorkout...');
  // Find test client user
  const clientUser = await prisma.user.findFirst({
    where: { role: 'CLIENT' },
    select: { id: true, name: true },
  });

  if (!clientUser) {
    console.error('FAIL: No client user found');
    process.exit(1);
  }
  console.log(`  Found client: ${clientUser.name} (${clientUser.id})`);

  const savedRecord = await workoutService.recordWorkout(clientUser.id, parseResult.data);
  console.log(`  ✓ Record saved successfully in DB! Record ID: ${savedRecord.id}`);
  console.log(`    Session Title: "${savedRecord.sessionTitle}"`);
  console.log(`    Duration: ${savedRecord.durationSeconds}s, Completed Sets: ${savedRecord.completedSetsCount}`);

  // 3. Verify database row
  const dbRecord = await prisma.workoutRecord.findUnique({
    where: { id: savedRecord.id },
    include: { exerciseRecords: true },
  });

  if (!dbRecord) {
    console.error('FAIL: Could not find created record in database');
    process.exit(1);
  }
  console.log(`  ✓ Database record verified: isCompleted=${dbRecord.isCompleted}, isLocked=${dbRecord.isLocked}, exercises=${dbRecord.exerciseRecords.length}\n`);

  // Cleanup test record
  await prisma.workoutRecord.delete({ where: { id: savedRecord.id } });
  console.log('  ✓ Test record cleaned up.');

  console.log('\n================================================================');
  console.log('🎉 ALL WORKOUT RECORD VALIDATION TESTS PASSED WITH 100% SUCCESS!');
  console.log('================================================================');
}

runTest()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Test error:', e);
    process.exit(1);
  });

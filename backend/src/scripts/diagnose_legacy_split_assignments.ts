import { prisma } from '../config/prisma';

async function diagnose() {
  console.log('=== ALPHA X GYM: WORKOUT SPLIT & SESSION DIAGNOSTIC ===\n');

  // 1. Inspect all workout sessions
  const sessions = await prisma.workoutSession.findMany({
    include: {
      exercises: {
        orderBy: { orderIndex: 'asc' },
      },
      assignments: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  console.log(`Found ${sessions.length} total workout sessions in database:`);
  let suspectCount = 0;

  for (const s of sessions) {
    const exCount = s.exercises.length;
    const isSuspect = exCount > 15; // Unusually high exercise count indicating concatenated multi-day split
    if (isSuspect) suspectCount++;

    console.log(`- [${s.id}] "${s.title}" (${s.workoutType})`);
    console.log(`  Schedule: "${s.recurringSchedule || 'N/A'}" | Availability: ${s.availabilityType} | Exercises: ${exCount} ${isSuspect ? '⚠️ SUSPECT CONCATENATED SESSION' : '✓'}`);
    console.log(`  Assignments: ${s.assignments.length} (Client IDs: ${s.assignments.map(a => a.clientId || 'ALL').join(', ')})`);

    if (isSuspect) {
      console.log(`  Exercises listed in suspect session:`);
      s.exercises.forEach((e, idx) => {
        console.log(`    ${idx + 1}. [${e.category}] ${e.exerciseName} (${e.numberOfSets} sets @ ${e.targetReps})`);
      });
    }
  }

  // 2. Inspect AI proposals that might contain weeklySchedule
  const proposals = await prisma.aIProposal.findMany({
    where: { proposalType: 'WORKOUT' },
    orderBy: { createdAt: 'desc' },
  });

  console.log(`\nFound ${proposals.length} workout AI proposals:`);
  for (const p of proposals) {
    let payload: any = {};
    try {
      payload = JSON.parse(p.finalDataJson || p.proposedDataJson || '{}');
    } catch (_) {}

    const hasSchedule = Array.isArray(payload.weeklySchedule) && payload.weeklySchedule.length > 0;
    console.log(`- [${p.id}] "${p.title}" | Status: ${p.status} | Has weeklySchedule: ${hasSchedule ? `YES (${payload.weeklySchedule.length} days)` : 'NO'}`);
  }

  console.log(`\n=== DIAGNOSTIC SUMMARY ===`);
  console.log(`Total sessions inspected: ${sessions.length}`);
  console.log(`Suspect concatenated sessions (>15 exercises): ${suspectCount}`);
  if (suspectCount === 0) {
    console.log(`✓ No active corrupted concatenated sessions (>15 exercises) found in production database.`);
  } else {
    console.log(`⚠️ Found ${suspectCount} sessions that may need review or repair.`);
  }

  await prisma.$disconnect();
}

diagnose().catch(err => {
  console.error('Diagnostic error:', err);
  process.exit(1);
});

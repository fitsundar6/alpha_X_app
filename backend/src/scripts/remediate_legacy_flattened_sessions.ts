import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * Utility script to audit and safely remediate legacy flattened workout sessions.
 * 
 * Safe by default: runs in DRY-RUN mode unless '--apply' is explicitly passed.
 * Does NOT delete client workout history or set logs.
 */
async function remediateLegacySessions() {
  const isApply = process.argv.includes('--apply');
  console.log(`\n=======================================================`);
  console.log(`ALPHA X — LEGACY FLATTENED WORKOUT REMEDIATION UTILITY`);
  console.log(`Mode: ${isApply ? '⚠️  LIVE EXECUTION (APPLYING CHANGES)' : '🛡️  DRY RUN (AUDIT ONLY — NO DATABASE WRITES)'}`);
  console.log(`=======================================================\n`);

  const suspectSessions = await prisma.workoutSession.findMany({
    where: {
      exercises: {
        some: {},
      },
    },
    include: {
      exercises: true,
      assignments: {
        include: {
          client: true,
        },
      },
    },
  });

  const flattenedSessions = suspectSessions.filter((s) => s.exercises.length >= 15);
  console.log(`Found ${flattenedSessions.length} suspect sessions with >= 15 exercises:\n`);

  for (const session of flattenedSessions) {
    console.log(`- Session ID: ${session.id}`);
    console.log(`  Title: "${session.title}"`);
    console.log(`  Exercise Count: ${session.exercises.length}`);
    console.log(`  Recurring Schedule: ${session.recurringSchedule || 'NULL (Defaulted to Monday)'}`);
    console.log(`  Active Assignments: ${session.assignments.filter(a => a.active).length}`);
    for (const a of session.assignments) {
      console.log(`    -> Assigned to: ${a.client?.name || a.clientId} (Active: ${a.active}, Scheduled: ${a.scheduledDate})`);
    }

    if (isApply) {
      // Deactivate active assignments for this corrupted flattened session
      const deactivated = await prisma.workoutAssignment.updateMany({
        where: { sessionId: session.id, active: true },
        data: { active: false },
      });
      console.log(`  [APPLIED] Deactivated ${deactivated.count} active assignments for session ${session.id}.`);

      // Mark session as inactive
      await prisma.workoutSession.update({
        where: { id: session.id },
        data: { isActive: false },
      });
      console.log(`  [APPLIED] Set session ${session.id} isActive = false.`);
    }
    console.log('');
  }

  if (!isApply && flattenedSessions.length > 0) {
    console.log(`🛡️  DRY RUN complete. Zero database records were modified.`);
    console.log(`To apply deactivation of corrupted legacy sessions and their assignments, run:`);
    console.log(`   npx ts-node src/scripts/remediate_legacy_flattened_sessions.ts --apply\n`);
  } else if (isApply) {
    console.log(`✅ Remediation complete. Corrupted legacy sessions successfully deactivated.\n`);
  }
}

remediateLegacySessions()
  .catch((e) => {
    console.error('Error during remediation:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

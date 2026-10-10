import { prisma } from './config/prisma';
import { workoutRepository } from './modules/workout/workout.repository';

async function verifyCleanliness() {
  console.log('==================================================');
  console.log('🔍 ALPHA X GYM — PRODUCTION CLEANLINESS VERIFICATION');
  console.log('==================================================\n');

  // 1. Verify Users
  const users = await prisma.user.findMany({
    select: { id: true, email: true, name: true, role: true, clientProfile: { select: { clientId: true } } },
    orderBy: { createdAt: 'asc' },
  });

  console.log(`1. Users in Database (${users.length}):`);
  const demoUsersFound: string[] = [];
  for (const u of users) {
    const isDemo = u.email.includes('test') || u.email.includes('marcus') || u.email.includes('athlete_') || u.email.includes('attacker');
    if (isDemo) {
      demoUsersFound.push(`${u.name} (${u.email}) [ID: ${u.id}]`);
    }
    console.log(`   - ${u.name} (${u.email}) [Role: ${u.role}, ClientID: ${u.clientProfile?.clientId ?? 'N/A'}]`);
  }

  // 2. Call workoutRepository methods to ensure NO auto-seeding occurs
  console.log('\n2. Testing WorkoutRepository auto-seed protection...');
  await workoutRepository.ensureDatabaseSeeded();
  const allSessions = await workoutRepository.getAllSessions();
  console.log(`   - Total sessions returned by getAllSessions(): ${allSessions.length}`);

  // 3. Verify Database Sessions
  const dbSessions = await prisma.workoutSession.findMany({
    select: { id: true, title: true, workoutType: true, availabilityType: true },
  });
  console.log(`\n3. Workout Sessions in Database (${dbSessions.length}):`);
  const demoSessionsFound: string[] = [];
  for (const s of dbSessions) {
    if (s.id.startsWith('ws_push_a') || s.id.startsWith('ws_pull_a') || s.id.startsWith('ws_legs_a')) {
      demoSessionsFound.push(`${s.title} [ID: ${s.id}]`);
    }
    console.log(`   - "${s.title}" [ID: ${s.id}, Type: ${s.workoutType}]`);
  }

  // 4. Verify Workout Assignments
  const assignments = await prisma.workoutAssignment.findMany({
    select: { id: true, sessionId: true, clientId: true, isRecommended: true },
  });
  console.log(`\n4. Workout Assignments in Database (${assignments.length}):`);
  for (const a of assignments) {
    console.log(`   - Assignment: ${a.id} -> Session: ${a.sessionId} -> Client: ${a.clientId ?? 'GLOBAL (null)'} (Recommended: ${a.isRecommended})`);
  }

  // 5. Verify Diet Plans
  const dietPlans = await prisma.dietPlan.findMany({
    select: { id: true, planName: true, clientId: true, isActive: true },
  });
  console.log(`\n5. Assigned Diet Plans in Database (${dietPlans.length}):`);
  const activeDietPlans = dietPlans.filter((p: any) => p.isActive);
  console.log(`   - Active diet plans: ${activeDietPlans.length}`);
  for (const p of activeDietPlans) {
    console.log(`     * "${p.planName}" -> Client: ${p.clientId}`);
  }

  // 6. Summary Evaluation
  console.log('\n==================================================');
  if (demoUsersFound.length === 0 && demoSessionsFound.length === 0) {
    console.log('✅ ALL PRODUCTION CLEANLINESS CHECKS PASSED!');
    console.log('   - 0 demo/test user accounts found.');
    console.log('   - 0 demo workout sessions recreated.');
    console.log('   - Only legitimate real client and coach data preserved.');
  } else {
    console.error('❌ CLEANLINESS FAILURE:');
    if (demoUsersFound.length > 0) console.error(`   - Demo users found: ${demoUsersFound.join(', ')}`);
    if (demoSessionsFound.length > 0) console.error(`   - Demo sessions found: ${demoSessionsFound.join(', ')}`);
    process.exit(1);
  }
  console.log('==================================================');

  await prisma.$disconnect();
}

verifyCleanliness().catch((e) => {
  console.error('Verification error:', e);
  process.exit(1);
});

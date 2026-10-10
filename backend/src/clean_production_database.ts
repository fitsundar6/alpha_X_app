import { prisma } from './config/prisma';

// The verified real production clients to strictly preserve
const PRESERVED_EMAILS = [
  'dranubharathi2498@gmail.com',
  'johnguru2510@gmail.com',
  'sakthiprabakar1515dsp@gnail.com',
];

async function main() {
  console.log('==================================================');
  console.log('🧹 ALPHA X GYM — PRODUCTION DATABASE CLEANUP');
  console.log('==================================================');

  // 1. Identify legitimate users to preserve
  const realUsers = await prisma.user.findMany({
    where: {
      email: { in: PRESERVED_EMAILS },
    },
    include: { clientProfile: true },
  });

  const realUserIds = realUsers.map((u) => u.id);
  console.log(`\n✔ Verified legitimate accounts to preserve (${realUsers.length}):`);
  for (const u of realUsers) {
    console.log(`   - ${u.name} (${u.email}) [ClientID: ${u.clientProfile?.clientId}]`);
  }

  if (realUsers.length === 0) {
    throw new Error('Safety check failed: Could not find any of the verified legitimate user accounts.');
  }

  // 2. Identify demo / test users to delete
  const demoUsers = await prisma.user.findMany({
    where: {
      id: { notIn: realUserIds },
    },
    include: { clientProfile: true },
  });

  console.log(`\n🗑 Identified demo & test accounts to remove (${demoUsers.length}):`);
  for (const u of demoUsers) {
    console.log(`   - [DELETE] ${u.name} (${u.email}) [ID: ${u.id}]`);
  }

  const demoUserIds = demoUsers.map((u) => u.id);
  const demoClientProfileIds = demoUsers
    .map((u) => u.clientProfile?.id)
    .filter(Boolean) as string[];

  // 3. Remove fake/demo diet plans (plans for demo users or Marcus Vance)
  const deletedDietPlans = await prisma.dietPlan.deleteMany({
    where: {
      OR: [
        { clientProfileId: { in: demoClientProfileIds } },
        { clientId: 'client_marcus_vance' },
        { clientId: { in: demoUserIds } },
      ],
    },
  });
  console.log(`✔ Deleted demo diet plans: ${deletedDietPlans.count}`);

  // 4. Remove fake/demo macro plans
  const deletedMacroPlans = await prisma.macroPlan.deleteMany({
    where: {
      OR: [
        { clientProfileId: { in: demoClientProfileIds } },
        { clientId: 'client_marcus_vance' },
        { clientId: { in: demoUserIds } },
      ],
    },
  });
  console.log(`✔ Deleted demo macro plans: ${deletedMacroPlans.count}`);

  // 5. Remove fake/demo food logs
  const deletedFoodLogs = await prisma.clientFoodLog.deleteMany({
    where: {
      OR: [
        { clientProfileId: { in: demoClientProfileIds } },
        { clientId: 'client_marcus_vance' },
        { clientId: { in: demoUserIds } },
      ],
    },
  });
  console.log(`✔ Deleted demo food logs: ${deletedFoodLogs.count}`);

  // 6. Remove fake/demo workout records
  const deletedWorkoutRecords = await prisma.workoutRecord.deleteMany({
    where: {
      clientId: { in: [...demoUserIds, 'client_marcus_vance'] },
    },
  });
  console.log(`✔ Deleted demo workout records: ${deletedWorkoutRecords.count}`);

  // 7. Remove demo / default workout assignments (including global "ALL" default assignments)
  const deletedAssignments = await prisma.workoutAssignment.deleteMany({
    where: {
      OR: [
        { clientId: null }, // Global default assignments (Push A, Pull A, Legs A assigned to ALL)
        { clientId: { in: [...demoUserIds, 'client_marcus_vance'] } },
      ],
    },
  });
  console.log(`✔ Deleted demo/global workout assignments: ${deletedAssignments.count}`);

  // 8. Remove demo workout sessions (ws_push_a_01, ws_pull_a_02, ws_legs_a_03, Marcus, Client Alpha, Upper Hypertrophy B)
  // Preserve sessions assigned to real clients (like "anu")
  const demoSessionIds = [
    'ws_push_a_01',
    'ws_pull_a_02',
    'ws_legs_a_03',
    '4a9d1b3d-6aeb-4cf8-885e-c5db8d51ebb5', // Client Alpha session
    'dc935fc4-c2fb-4110-9e1e-da4e881c7555', // Marcus Vance session
    'ws_1791531664490', // Upper Hypertrophy B
  ];

  const deletedSessions = await prisma.workoutSession.deleteMany({
    where: {
      id: { in: demoSessionIds },
    },
  });
  console.log(`✔ Deleted demo workout sessions: ${deletedSessions.count}`);

  // 9. Remove all demo users (User deletion cascades to client_profiles, reset codes, verification logs)
  if (demoUserIds.length > 0) {
    const deletedUsers = await prisma.user.deleteMany({
      where: {
        id: { in: demoUserIds },
      },
    });
    console.log(`✔ Deleted demo user accounts: ${deletedUsers.count}`);
  }

  console.log('\n==================================================');
  console.log('✨ CLEANUP COMPLETE — DATABASE STATUS:');
  console.log('==================================================');

  const remainingUsers = await prisma.user.findMany({
    include: { clientProfile: true },
  });
  console.log(`Remaining Users in DB (${remainingUsers.length}):`);
  for (const u of remainingUsers) {
    console.log(`   - ${u.name} (${u.email}) [ClientID: ${u.clientProfile?.clientId}]`);
  }

  const remainingSessions = await prisma.workoutSession.findMany({
    select: { id: true, title: true, availabilityType: true },
  });
  console.log(`Remaining Workout Sessions (${remainingSessions.length}):`);
  for (const s of remainingSessions) {
    console.log(`   - "${s.title}" [ID: ${s.id}]`);
  }

  const remainingAssignments = await prisma.workoutAssignment.findMany({
    select: { id: true, sessionId: true, clientId: true },
  });
  console.log(`Remaining Workout Assignments (${remainingAssignments.length}):`);
  for (const a of remainingAssignments) {
    console.log(`   - Session: ${a.sessionId} -> Client: ${a.clientId}`);
  }

  const remainingDietPlans = await prisma.dietPlan.findMany({
    select: { id: true, clientId: true, planName: true, isActive: true },
  });
  console.log(`Remaining Diet Plans (${remainingDietPlans.length}):`);
  for (const d of remainingDietPlans) {
    console.log(`   - "${d.planName}" -> Client: ${d.clientId} (Active: ${d.isActive})`);
  }

  const remainingRecords = await prisma.workoutRecord.count();
  console.log(`Remaining Real Workout Records: ${remainingRecords}`);

  const remainingFoodLogs = await prisma.clientFoodLog.count();
  console.log(`Remaining Real Food Logs: ${remainingFoodLogs}`);

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error('Cleanup error:', err);
  process.exit(1);
});

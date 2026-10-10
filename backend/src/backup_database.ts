import fs from 'fs';
import path from 'path';
import { prisma } from './config/prisma';

async function main() {
  console.log('🔄 Starting full database backup...');
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.resolve(__dirname, '../backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }
  const backupFile = path.join(backupDir, `db_backup_${timestamp}.json`);

  const backupData: Record<string, any> = {
    metadata: {
      timestamp: new Date().toISOString(),
      databaseUrl: process.env.DATABASE_URL ? 'configured' : 'missing',
    },
    users: await prisma.user.findMany(),
    clientProfiles: await prisma.clientProfile.findMany(),
    workoutSessions: await prisma.workoutSession.findMany({
      include: {
        exercises: {
          include: { setTemplates: true },
        },
      },
    }),
    workoutAssignments: await prisma.workoutAssignment.findMany(),
    workoutRecords: await prisma.workoutRecord.findMany({
      include: {
        exerciseRecords: {
          include: { setRecords: true },
        },
      },
    }),
    dietPlans: await prisma.dietPlan.findMany(),
    dietPlanHistories: await prisma.dietPlanHistory.findMany(),
    clientFoodLogs: await prisma.clientFoodLog.findMany(),
    macroPlans: await prisma.macroPlan.findMany(),
    clientProgress: await prisma.clientProgress.findMany(),
    activityRecords: await prisma.activityRecord.findMany(),
    stepGoalHistories: await prisma.stepGoalHistory.findMany(),
    weeklyCheckIns: await prisma.weeklyCheckIn.findMany(),
    mealPhotos: await prisma.mealPhoto.findMany(),
    notifications: await prisma.notification.findMany(),
    transformationMilestones: await prisma.transformationMilestone.findMany(),
    userVerificationLogs: await prisma.userVerificationLog.findMany(),
    aiProposals: await (prisma as any).aIProposal.findMany(),
  };

  fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2), 'utf-8');
  console.log(`✔ Database successfully backed up to: ${backupFile}`);
  console.log(`📊 Backup summary:`);
  console.log(`   - Users: ${backupData.users.length}`);
  console.log(`   - Client Profiles: ${backupData.clientProfiles.length}`);
  console.log(`   - Workout Sessions: ${backupData.workoutSessions.length}`);
  console.log(`   - Workout Assignments: ${backupData.workoutAssignments.length}`);
  console.log(`   - Workout Records: ${backupData.workoutRecords.length}`);
  console.log(`   - Diet Plans: ${backupData.dietPlans.length}`);
  console.log(`   - Food Logs: ${backupData.clientFoodLogs.length}`);
  console.log(`   - Macro Plans: ${backupData.macroPlans.length}`);

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error('Backup failed:', err);
  process.exit(1);
});

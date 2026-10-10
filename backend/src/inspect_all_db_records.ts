import { prisma } from './config/prisma';

async function main() {
  const users = await prisma.user.findMany({
    include: { clientProfile: true },
    orderBy: { createdAt: 'asc' },
  });
  console.log(`=== USERS (${users.length}) ===`);
  for (const u of users) {
    console.log(`ID: ${u.id} | Email: ${u.email} | Name: ${u.name} | Role: ${u.role} | Status: ${u.status} | ClientID: ${u.clientProfile?.clientId}`);
  }

  const sessions = await prisma.workoutSession.findMany({
    select: { id: true, title: true, createdById: true, availabilityType: true },
  });
  console.log(`\n=== WORKOUT SESSIONS (${sessions.length}) ===`);
  for (const s of sessions) {
    console.log(`ID: ${s.id} | Title: ${s.title} | CreatedBy: ${s.createdById} | Type: ${s.availabilityType}`);
  }

  const assignments = await prisma.workoutAssignment.findMany({
    select: { id: true, sessionId: true, clientId: true, active: true },
  });
  console.log(`\n=== WORKOUT ASSIGNMENTS (${assignments.length}) ===`);
  for (const a of assignments) {
    console.log(`ID: ${a.id} | SessionId: ${a.sessionId} | ClientId: ${a.clientId} | Active: ${a.active}`);
  }

  const records = await prisma.workoutRecord.findMany({
    select: { id: true, clientId: true, sessionTitle: true, startedAt: true },
  });
  console.log(`\n=== WORKOUT RECORDS (${records.length}) ===`);
  for (const r of records) {
    console.log(`ID: ${r.id} | ClientId: ${r.clientId} | Title: ${r.sessionTitle} | StartedAt: ${r.startedAt}`);
  }

  const dietPlans = await prisma.dietPlan.findMany({
    select: { id: true, clientId: true, planName: true, isActive: true },
  });
  console.log(`\n=== DIET PLANS (${dietPlans.length}) ===`);
  for (const d of dietPlans) {
    console.log(`ID: ${d.id} | ClientId: ${d.clientId} | PlanName: ${d.planName} | Active: ${d.isActive}`);
  }

  const macroPlans = await prisma.macroPlan.findMany({
    select: { id: true, clientId: true, calories: true, isActive: true },
  });
  console.log(`\n=== MACRO PLANS (${macroPlans.length}) ===`);
  for (const m of macroPlans) {
    console.log(`ID: ${m.id} | ClientId: ${m.clientId} | Calories: ${m.calories} | Active: ${m.isActive}`);
  }

  const progress = await prisma.clientProgress.findMany({
    select: { id: true, clientId: true, weightKg: true, date: true },
  });
  console.log(`\n=== CLIENT PROGRESS (${progress.length}) ===`);
  for (const p of progress) {
    console.log(`ID: ${p.id} | ClientId: ${p.clientId} | Weight: ${p.weightKg} | Date: ${p.date}`);
  }

  const foodLogs = await prisma.clientFoodLog.findMany({
    select: { id: true, clientId: true, foodName: true, dateString: true },
  });
  console.log(`\n=== FOOD LOGS (${foodLogs.length}) ===`);
  for (const f of foodLogs) {
    console.log(`ID: ${f.id} | ClientId: ${f.clientId} | Food: ${f.foodName} | Date: ${f.dateString}`);
  }

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

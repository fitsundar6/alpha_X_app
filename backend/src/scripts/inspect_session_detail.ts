import { prisma } from '../config/prisma';
async function main() {
  const s = await prisma.workoutSession.findUnique({
    where: { id: 'b8986b96-a159-4702-9b72-e91fef2c5cfb' },
    include: { assignments: true, exercises: true }
  });
  console.log('Session details:', JSON.stringify(s, null, 2));

  // Also check AI audit logs around the same time
  if (s) {
    const logs = await prisma.aIAuditLog.findMany({
      where: {
        createdAt: {
          gte: new Date(s.createdAt.getTime() - 60000),
          lte: new Date(s.createdAt.getTime() + 60000)
        }
      }
    });
    console.log('Audit logs around session creation:', JSON.stringify(logs, null, 2));
  }
}
main().finally(() => prisma.$disconnect());

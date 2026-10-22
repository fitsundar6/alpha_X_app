import { prisma } from './config/prisma';

async function check() {
  const a = await prisma.workoutAssignment.findMany({
    where: { client: { email: 'akilar@gmail.com' } },
    include: { session: true }
  });
  console.log('Akilar assignments:', a.map(x => ({
    id: x.id,
    sessionTitle: x.session.title,
    sessionCreatedBy: x.session.createdById,
    assignedById: x.assignedById,
    scheduledDate: x.scheduledDate,
    status: x.status
  })));

  const records = await prisma.workoutRecord.findMany({
    where: { client: { email: 'akilar@gmail.com' } }
  });
  console.log('Akilar workout records:', records.map(r => ({
    id: r.id,
    sessionTitle: r.sessionTitle,
    workoutType: r.workoutType,
    startedAt: r.startedAt,
    completedAt: r.completedAt
  })));
  await prisma.$disconnect();
}
check();

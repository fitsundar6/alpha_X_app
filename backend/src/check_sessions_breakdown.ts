import { prisma } from './config/prisma';

async function checkSessions() {
  const sessions = await prisma.workoutSession.findMany({
    include: {
      assignments: {
        include: {
          client: {
            select: { id: true, email: true, name: true }
          }
        }
      }
    }
  });

  const realEmails = [
    'fitsundar6@gmail.com',
    'dranubharathi2498@gmail.com',
    'akilar@gmail.com',
    'ajaymaathank@gmail.com',
    'johnguru2510@gmail.com',
    'sakthiprabakar1515dsp@gnail.com',
    'sundar@gmail.com',
    'subashmari.m@gmail.com',
    'monalisanavaneethan98@gmail.com',
    'pnandheeswaran332@gmail.com',
    'shyamanandraj04@gmail.com',
    'iamraj3646@gmail.com'
  ];

  let dummySessions = [];
  let realSessions = [];

  for (const s of sessions) {
    const assignedRealClients = s.assignments.filter(a => a.client && realEmails.includes(a.client.email));
    if (assignedRealClients.length > 0 || (s.availabilityType === 'ALL' && s.createdById !== 'admin_editing_test' && s.createdById !== 'admin_flex_test' && s.createdById !== 'admin_reg_coach')) {
      realSessions.push({ id: s.id, title: s.title, createdById: s.createdById, realClients: assignedRealClients.map(a => a.client?.email) });
    } else {
      dummySessions.push({ id: s.id, title: s.title, createdById: s.createdById, totalAssignments: s.assignments.length });
    }
  }

  console.log(`Total sessions: ${sessions.length}`);
  console.log(`Real/Protected sessions: ${realSessions.length}`);
  console.log(`Dummy sessions (only assigned to test users or unassigned test templates): ${dummySessions.length}`);

  // Group dummy sessions by createdById
  const dummyByCreator: Record<string, number> = {};
  for (const ds of dummySessions) {
    dummyByCreator[ds.createdById || 'null'] = (dummyByCreator[ds.createdById || 'null'] || 0) + 1;
  }
  console.log('Dummy sessions by creator:', dummyByCreator);

  await prisma.$disconnect();
}
checkSessions();

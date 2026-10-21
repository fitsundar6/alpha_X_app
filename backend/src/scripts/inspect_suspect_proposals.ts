import { prisma } from '../config/prisma';
async function main() {
  const ids = [
    'b784888b-d484-42a1-a4e1-aef5e3e7947f',
    '71fa9a6a-5ced-441a-87e4-1d3027bbe4bc',
    'd4940d73-58d0-4b7e-9d28-9a544d0bfe71',
    'b8986b96-a159-4702-9b72-e91fef2c5cfb'
  ];
  const props = await prisma.aIProposal.findMany({
    where: {
      OR: [
        { id: { in: ids } },
        { title: { contains: 'Sakthiprabakar' } }
      ]
    }
  });
  for (const p of props) {
    console.log('=== PROPOSAL', p.id, p.title, p.status, '===');
    const proposed = JSON.parse(p.proposedDataJson || '{}');
    console.log('proposed weeklySchedule length:', proposed.weeklySchedule?.length);
    console.log('proposed exercises length:', proposed.exercises?.length);
    if (proposed.weeklySchedule) {
      console.log('days:', proposed.weeklySchedule.map((d: any) => ({ day: d.day || d.dayName, title: d.sessionTitle, exCount: d.exercises?.length })));
    }
    if (p.finalDataJson) {
      const final = JSON.parse(p.finalDataJson);
      console.log('final weeklySchedule length:', final.weeklySchedule?.length);
      console.log('final exercises length:', final.exercises?.length);
      if (final.weeklySchedule) {
        console.log('final days:', final.weeklySchedule.map((d: any) => ({ day: d.day || d.dayName, title: d.sessionTitle, exCount: d.exercises?.length })));
      }
    } else {
      console.log('finalDataJson is NULL');
    }
  }

  // Also inspect suspect sessions and their assignments
  const suspectSessions = await prisma.workoutSession.findMany({
    where: {
      id: { in: [
        'ai_draft_b784888b-d484-42a1-a4e1-aef5e3e7947f',
        'ai_draft_71fa9a6a-5ced-441a-87e4-1d3027bbe4bc',
        'ai_draft_d4940d73-58d0-4b7e-9d28-9a544d0bfe71',
        'b8986b96-a159-4702-9b72-e91fef2c5cfb'
      ] }
    },
    include: {
      assignments: true,
      exercises: true
    }
  });
  console.log('\n=== SUSPECT SESSIONS DETAIL ===');
  for (const s of suspectSessions) {
    console.log(`Session: ${s.id} | Title: "${s.title}" | recurringSchedule: "${s.recurringSchedule}" | Exercises: ${s.exercises.length}`);
    for (const a of s.assignments) {
      console.log(`  Assignment: id: ${a.id} | clientId: ${a.clientId} | scheduledDate: ${a.scheduledDate} | active: ${a.active}`);
    }
  }
}
main().finally(() => prisma.$disconnect());

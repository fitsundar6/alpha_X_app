import { prisma } from '../config/prisma';

async function main() {
  console.log('Synchronizing Client IDs for existing profiles...');
  const profiles = await prisma.clientProfile.findMany({
    where: { clientId: null },
    orderBy: { createdAt: 'asc' },
  });

  console.log(`Found ${profiles.length} profiles without clientId.`);
  let counter = 1;

  for (const profile of profiles) {
    let assigned = false;
    while (!assigned) {
      const candidateId = `AXG-${String(counter).padStart(4, '0')}`;
      const existing = await prisma.clientProfile.findUnique({
        where: { clientId: candidateId },
      });
      if (!existing) {
        await prisma.clientProfile.update({
          where: { id: profile.id },
          data: { clientId: candidateId },
        });
        console.log(`Assigned ${candidateId} to profile ${profile.id}`);
        assigned = true;
      }
      counter++;
    }
  }

  console.log('Client ID synchronization complete.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Error synchronizing Client IDs:', err);
  process.exit(1);
});

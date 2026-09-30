import { prisma } from './config/prisma';

async function main() {
  const users = await prisma.user.findMany({
    include: {
      clientProfile: true,
    },
    orderBy: { createdAt: 'desc' },
  });
  console.log(`Total users in DB: ${users.length}`);
  for (const u of users) {
    console.log(`[${u.createdAt.toISOString()}] ${u.clientProfile?.clientId} | ${u.name} | ${u.email} | onboardingCompleted: ${u.clientProfile?.onboardingCompleted}`);
  }
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

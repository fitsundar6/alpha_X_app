import { prisma } from './config/prisma';

async function checkAI() {
  const convos = await prisma.aIConversation.findMany({
    select: { id: true, adminId: true, title: true, activeClientId: true, createdAt: true }
  });
  console.log('AI Conversations:', convos);

  const proposals = await prisma.aIProposal.findMany({
    select: { id: true, clientProfileId: true, clientId: true, clientName: true, proposalType: true, status: true, approvedById: true }
  });
  console.log('AI Proposals:', proposals);

  const audits = await prisma.aIAuditLog.findMany({
    select: { id: true, adminId: true, clientName: true, action: true, createdAt: true }
  });
  console.log('AI Audit Logs count:', audits.length);

  await prisma.$disconnect();
}
checkAI();

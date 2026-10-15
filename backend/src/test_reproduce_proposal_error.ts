import { prisma } from './config/prisma';
import { geminiService } from './modules/ai_coach/gemini.service';

async function main() {
  console.log('=== STEP 1: VERIFY CLIENT AJAY IN DB ===');
  const clientUser = await prisma.user.findFirst({
    where: { role: 'CLIENT', name: { contains: 'Ajay' } },
    include: { clientProfile: true },
  });
  console.log('Client User:', clientUser?.id, clientUser?.name, clientUser?.clientProfile?.clientId);

  console.log('\n=== STEP 2: TEST REAL GEMINI AI CALL TO PROPOSE WORKOUT FOR AJAY ===');
  const testConvId = `conv_test_repro_${Date.now()}`;
  try {
    await prisma.aIConversation.create({
      data: {
        id: testConvId,
        adminId: 'admin_alex_stone',
        title: 'Repro Test Conversation',
      },
    });

    const res = await geminiService.generateFitnessResponse({
      message: 'Create a 4-week hypertrophy workout plan for Ajay (AXG-0005)',
      adminId: 'admin_alex_stone',
      requestId: 'req_repro_1',
      conversationId: testConvId,
      model: 'gemini-3.5-flash',
    });

    console.log('\nGemini response result:');
    console.log('Reply Text:', res.replyText);
    console.log('Tools Invoked:', res.toolsInvokedNames);
    console.log('Proposal:', JSON.stringify(res.proposal, null, 2));
  } catch (err: any) {
    console.error('Gemini call error caught:', err);
    console.error('Stack:', err.stack);
  }

  process.exit(0);
}

main().catch((e) => {
  console.error('FATAL:', e);
  process.exit(1);
});

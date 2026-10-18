/**
 * Alpha X Gym — Direct Sweep & Automation CLI Trigger
 *
 * Usage:
 *   npx ts-node src/trigger_sweep.ts                          # Safe Dry-Run (evaluates all clients, zero pushes)
 *   npx ts-node src/trigger_sweep.ts --test=AXG-0008          # Send test push directly to Sundar
 *   npx ts-node src/trigger_sweep.ts --test=AXG-0008 --category=WORKOUT_MOTIVATION
 *   npx ts-node src/trigger_sweep.ts --live                   # Live sweep send to all eligible clients
 *   npx ts-node src/trigger_sweep.ts --category=PROTEIN_GOAL
 */

import { fitnessEngagementService, EngagementCategory } from './modules/notifications/fitness_engagement.service';

async function main() {
  const args = process.argv.slice(2);
  const isLive = args.includes('--live');
  const isForce = args.includes('--force');

  let selectedCategory: EngagementCategory | undefined;
  const catArg = args.find((a) => a.startsWith('--category='));
  if (catArg) {
    selectedCategory = catArg.split('=')[1].toUpperCase() as EngagementCategory;
  }

  // Check if targeting a single client
  const testArg = args.find((a) => a.startsWith('--test=') || a.startsWith('--client='));
  const targetClient = testArg ? testArg.split('=')[1] : null;

  if (targetClient) {
    const category = selectedCategory || 'HYDRATION';
    console.log('======================================================================');
    console.log('ALPHA X GYM — SINGLE CLIENT TEST DISPATCH');
    console.log('======================================================================');
    console.log(`  Target Client:  ${targetClient}`);
    console.log(`  Category:       ${category}`);
    console.log(`  Force:          ${isForce} (bypasses quiet hours)`);
    console.log('======================================================================\n');

    const result = await fitnessEngagementService.sendTestEngagementNotification(
      'CLI_ADMIN',
      targetClient,
      category,
      true // force: true allows admin test push anytime, even during quiet hours
    );

    console.log('\n----------------------------------------------------------------------');
    console.log('TEST PUSH DISPATCH RESULT');
    console.log('----------------------------------------------------------------------');
    console.log(`  Success:         ${result.success ? '✅ YES' : '❌ NO'}`);
    console.log(`  Client Name:     ${result.clientName} (${result.clientId})`);
    console.log(`  External ID:     ${result.externalId}`);
    console.log(`  Title:           ${result.title}`);
    console.log(`  Message:         ${result.message}`);
    console.log(`  Delivery Status: ${result.status}`);
    if (result.notificationId) {
      console.log(`  OneSignal ID:    ${result.notificationId}`);
    }
    if (result.error) {
      console.log(`  Error:           ${result.error}`);
    }
    console.log('----------------------------------------------------------------------\n');
    process.exit(result.success ? 0 : 1);
  }

  const isDryRun = !isLive;
  console.log('======================================================================');
  console.log('ALPHA X GYM — FITNESS ENGAGEMENT SWEEP RUNNER');
  console.log('======================================================================');
  console.log(`  Mode:        ${isDryRun ? '🔍 SAFE DRY-RUN (Zero pushes sent)' : '🚀 LIVE (Dispatches pushes to eligible clients)'}`);
  console.log(`  Category:    ${selectedCategory || 'ALL_CONFIGURED_FOR_CURRENT_HOUR'}`);
  console.log('======================================================================\n');

  const result = await fitnessEngagementService.runEngagementSweep(selectedCategory, isDryRun, isForce);

  console.log('\n----------------------------------------------------------------------');
  console.log('SWEEP EXECUTION SUMMARY');
  console.log('----------------------------------------------------------------------');
  console.log(`  Clients Evaluated:  ${result.evaluated}`);
  console.log(`  Eligible / Sent:    ${result.sent}`);
  console.log(`  Skipped (No goal/DND/Opt-out): ${result.skipped}`);
  console.log(`  Duplicates Dropped: ${result.duplicate}`);
  console.log(`  Dry Run:            ${result.dryRun}`);
  console.log(`  Timestamp:          ${result.timestamp}`);
  console.log('----------------------------------------------------------------------\n');

  process.exit(0);
}

main().catch((err) => {
  console.error('[SWEEP ERROR]:', err);
  process.exit(1);
});

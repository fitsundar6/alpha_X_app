/**
 * Alpha X Gym — Direct Sweep & Automation CLI Trigger
 *
 * Usage:
 *   npx ts-node src/trigger_sweep.ts            # Safe Dry-Run (evaluates all clients, zero pushes)
 *   npx ts-node src/trigger_sweep.ts --live     # Live send to eligible clients
 *   npx ts-node src/trigger_sweep.ts --category=HYDRATION
 *   npx ts-node src/trigger_sweep.ts --category=PROTEIN_GOAL
 *   npx ts-node src/trigger_sweep.ts --category=WORKOUT_MOTIVATION
 */

import { fitnessEngagementService, EngagementCategory } from './modules/notifications/fitness_engagement.service';

async function main() {
  const args = process.argv.slice(2);
  const isLive = args.includes('--live');
  const isDryRun = !isLive;

  let selectedCategory: EngagementCategory | undefined;
  const catArg = args.find((a) => a.startsWith('--category='));
  if (catArg) {
    selectedCategory = catArg.split('=')[1].toUpperCase() as EngagementCategory;
  }

  console.log('======================================================================');
  console.log('ALPHA X GYM — FITNESS ENGAGEMENT SWEEP RUNNER');
  console.log('======================================================================');
  console.log(`  Mode:        ${isDryRun ? '🔍 SAFE DRY-RUN (Zero pushes sent)' : '🚀 LIVE (Dispatches pushes to eligible clients)'}`);
  console.log(`  Category:    ${selectedCategory || 'ALL_CONFIGURED_FOR_CURRENT_HOUR'}`);
  console.log('======================================================================\n');

  const result = await fitnessEngagementService.runEngagementSweep(selectedCategory, isDryRun);

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

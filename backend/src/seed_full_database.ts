import { exerciseService } from './modules/exercise/exercise.service';
import { foodService } from './modules/food/food.service';
import { prisma } from './config/prisma';

async function main() {
  console.log('==============================================');
  console.log('🚀 SEEDING POSTGRESQL DATABASE (PRISMA)');
  console.log('==============================================');

  console.log('\n1. Seeding Exercises...');
  const exResult = await exerciseService.seedDatabase();
  console.log(`✔ Exercises seeded: ${exResult.inserted} inserted, ${exResult.existing} existing.`);
  const exCount = await prisma.exercise.count();
  console.log(`📊 Total Exercises now in PostgreSQL DB: ${exCount}`);

  console.log('\n2. Seeding Foods...');
  const foodResult = await foodService.seedDatabase();
  console.log(`✔ Foods seeded: ${foodResult.inserted} inserted, ${foodResult.existing} existing.`);
  const foodCount = await prisma.food.count();
  console.log(`📊 Total Foods now in PostgreSQL DB: ${foodCount}`);

  console.log('\n==============================================');
  console.log('✔ DATABASE SEEDING COMPLETED SUCCESSFULLY!');
  console.log('==============================================');

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});

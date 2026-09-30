import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  const foodCount = await prisma.food.count();
  const exerciseCount = await prisma.exercise.count();
  console.log('Food count in DB:', foodCount);
  console.log('Exercise count in DB:', exerciseCount);
  await prisma.$disconnect();
}

main();


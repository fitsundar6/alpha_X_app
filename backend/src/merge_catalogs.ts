import * as fs from 'fs';
import * as path from 'path';
import { INITIAL_EXERCISE_CATALOG } from './modules/exercise/exercise.seed';
import { ADDITIONAL_EXERCISES } from './additional_exercises_catalog';
import { INITIAL_FOOD_CATALOG } from './modules/food/food.seed';
import { ADDITIONAL_FOODS } from './additional_foods_catalog';
import { ExerciseDto } from './modules/exercise/exercise.types';
import { FoodDto } from './modules/food/food.types';

console.log('--- STARTING CATALOG MERGER ---');

// 1. MERGE EXERCISES
console.log(`Original exercise count: ${INITIAL_EXERCISE_CATALOG.length}`);
const exerciseMap = new Map<string, ExerciseDto>();

for (const ex of INITIAL_EXERCISE_CATALOG) {
  exerciseMap.set(ex.id, ex);
}

let newExercisesAdded = 0;
for (const add of ADDITIONAL_EXERCISES) {
  if (!exerciseMap.has(add.id)) {
    const isCompound = add.movementPattern.toLowerCase().includes('push') ||
      add.movementPattern.toLowerCase().includes('pull') ||
      add.movementPattern.toLowerCase().includes('squat') ||
      add.movementPattern.toLowerCase().includes('hinge') ||
      add.movementPattern.toLowerCase().includes('carry');

    const dto: ExerciseDto = {
      id: add.id,
      externalId: null,
      name: add.name,
      normalizedName: add.name.trim().toLowerCase(),
      aliases: [add.name.trim().toLowerCase()],
      description: add.description,
      instructions: [...add.setupInstructions, ...add.executionSteps],
      coachingCues: add.coachingCues,
      commonMistakes: add.commonMistakes,
      primaryMuscles: add.primaryMuscles.map(m => m.replace('MuscleGroup.', '').replace(/([A-Z])/g, ' $1').trim()),
      secondaryMuscles: add.secondaryMuscles.map(m => m.replace('MuscleGroup.', '').replace(/([A-Z])/g, ' $1').trim()),
      bodyPart: add.category,
      category: add.category,
      subcategory: add.subCategory,
      equipment: add.equipment,
      movementPattern: add.movementPattern,
      exerciseType: add.exerciseType,
      difficulty: add.difficulty,
      mechanics: isCompound ? 'Compound' : 'Isolation',
      forceType: 'Dynamic',
      planeOfMotion: 'Sagittal',
      laterality: 'Bilateral',
      isCompound,
      isIsolation: !isCompound,
      isUnilateral: false,
      imageUrl: '',
      videoUrl: '',
      thumbnailUrl: '',
      variations: [],
      progressions: [],
      regressions: [],
      alternativeExercises: [],
      source: 'Alpha X Gym Curated Catalog',
      sourceUrl: '',
      license: 'Proprietary Commercial License',
      licenseAuthor: 'Alpha X Gym Coaching Staff',
      isImported: false,
      isCustom: false,
      isActive: true,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    };
    exerciseMap.set(add.id, dto);
    newExercisesAdded++;
  }
}

const finalExercises = Array.from(exerciseMap.values());
console.log(`New exercises added: ${newExercisesAdded}`);
console.log(`Total merged exercises: ${finalExercises.length}`);

// Write merged exercise seed
const exerciseSeedPath = path.resolve(__dirname, 'modules/exercise/exercise.seed.ts');
const exerciseFileContent = `import { ExerciseDto } from './exercise.types';\n\nexport const INITIAL_EXERCISE_CATALOG: ExerciseDto[] = ${JSON.stringify(finalExercises, null, 2)};\n`;
fs.writeFileSync(exerciseSeedPath, exerciseFileContent, 'utf8');
console.log(`✔ Written updated exercise seed to ${exerciseSeedPath}`);

// 2. MERGE FOODS
console.log(`\nOriginal food count: ${INITIAL_FOOD_CATALOG.length}`);
const foodMap = new Map<string, Omit<FoodDto, 'createdAt' | 'updatedAt'>>();

for (const f of INITIAL_FOOD_CATALOG) {
  foodMap.set(f.id, f);
}

let newFoodsAdded = 0;
for (const add of ADDITIONAL_FOODS) {
  if (!foodMap.has(add.id)) {
    foodMap.set(add.id, add);
    newFoodsAdded++;
  }
}

const finalFoods = Array.from(foodMap.values());
console.log(`New foods added: ${newFoodsAdded}`);
console.log(`Total merged foods: ${finalFoods.length}`);

// Write merged food seed
const foodSeedPath = path.resolve(__dirname, 'modules/food/food.seed.ts');
const foodFileContent = `import { FoodDto } from './food.types';\n\nexport const INITIAL_FOOD_CATALOG: Omit<FoodDto, 'createdAt' | 'updatedAt'>[] = ${JSON.stringify(finalFoods, null, 2)};\n`;
fs.writeFileSync(foodSeedPath, foodFileContent, 'utf8');
console.log(`✔ Written updated food seed to ${foodSeedPath}`);

console.log('\n--- MERGER COMPLETED SUCCESSFULLY ---');

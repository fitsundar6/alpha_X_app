import * as fs from 'fs';
import * as path from 'path';

const catalogPath = path.resolve(__dirname, '../../apps/mobile/lib/features/exercise/data/default_exercise_catalog.dart');
const catalogContent = fs.readFileSync(catalogPath, 'utf8');

const seedPath = path.resolve(__dirname, 'modules/exercise/exercise.seed.ts');

// Parse exercises from Dart catalog
const exerciseBlocks = catalogContent.split(/Exercise\s*\(/g).slice(1);
console.log(`Parsing ${exerciseBlocks.length} exercises from Dart catalog...`);

interface ParsedEx {
  id: string;
  name: string;
  category: string;
  subCategory?: string;
  equipment: string;
  movementPattern: string;
  difficulty: string;
  exerciseType: string;
  description: string;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  setupInstructions: string[];
  executionSteps: string[];
  coachingCues: string[];
  commonMistakes: string[];
  defaultTrainerNote: string;
  tags: string[];
}

function extractString(block: string, key: string): string {
  const match = block.match(new RegExp(`${key}:\\s*'([^']*)'`, 'i'));
  return match ? match[1] : '';
}

function extractList(block: string, key: string): string[] {
  const match = block.match(new RegExp(`${key}:\\s*(?:const\\s*)?\\[([^\\]]*)\\]`, 's'));
  if (!match) return [];
  const inside = match[1];
  const items: string[] = [];
  const stringMatches = inside.matchAll(/'([^']*)'/g);
  for (const sm of stringMatches) {
    items.push(sm[1]);
  }
  return items;
}

function extractMuscleList(block: string, key: string): string[] {
  const match = block.match(new RegExp(`${key}:\\s*\\[([^\\]]*)\\]`, 's'));
  if (!match) return [];
  const inside = match[1];
  const matches = inside.match(/MuscleGroup\.([a-zA-Z0-9]+)/g) || [];
  return matches.map((m) => {
    const raw = m.replace('MuscleGroup.', '');
    // Convert camelCase to Title Case
    return raw.replace(/([A-Z])/g, ' $1').replace(/^./, (str) => str.toUpperCase()).trim();
  });
}

const parsedExercises: ParsedEx[] = [];

for (const block of exerciseBlocks) {
  const id = extractString(block, 'id');
  const name = extractString(block, 'name');
  if (!id || !name) continue;

  const category = extractString(block, 'category');
  const subCategory = extractString(block, 'subCategory');
  const equipment = extractString(block, 'equipment');
  const movementPattern = extractString(block, 'movementPattern');
  const difficulty = extractString(block, 'difficulty') || 'Intermediate';
  const exerciseType = extractString(block, 'exerciseType') || 'Strength';
  const description = extractString(block, 'description');
  const defaultTrainerNote = extractString(block, 'defaultTrainerNote');

  const primaryMuscles = extractMuscleList(block, 'primaryMuscles');
  const secondaryMuscles = extractMuscleList(block, 'secondaryMuscles');
  const setupInstructions = extractList(block, 'setupInstructions');
  const executionSteps = extractList(block, 'executionSteps');
  const coachingCues = extractList(block, 'coachingCues');
  const commonMistakes = extractList(block, 'commonMistakes');
  const tags = extractList(block, 'tags');

  parsedExercises.push({
    id,
    name,
    category,
    subCategory,
    equipment,
    movementPattern,
    difficulty,
    exerciseType,
    description,
    primaryMuscles,
    secondaryMuscles,
    setupInstructions,
    executionSteps,
    coachingCues,
    commonMistakes,
    defaultTrainerNote,
    tags,
  });
}

console.log(`Successfully parsed ${parsedExercises.length} exercises.`);

// Build TypeScript exercise seed file
let tsContent = `import { ExerciseDto } from './exercise.types';\n\n`;
tsContent += `export const INITIAL_EXERCISE_CATALOG: ExerciseDto[] = [\n`;

for (const ex of parsedExercises) {
  const normalizedName = ex.name.toLowerCase().trim();
  const allInstructions = [...ex.setupInstructions, ...ex.executionSteps];
  if (allInstructions.length === 0) {
    allInstructions.push(ex.description || `Perform ${ex.name} with controlled tempo.`);
  }

  tsContent += `  {
    id: ${JSON.stringify(ex.id)},
    externalId: ${JSON.stringify('wger_' + ex.id)},
    name: ${JSON.stringify(ex.name)},
    normalizedName: ${JSON.stringify(normalizedName)},
    aliases: [${JSON.stringify(normalizedName)}],
    description: ${JSON.stringify(ex.description || ex.name)},
    instructions: ${JSON.stringify(allInstructions)},
    coachingCues: ${JSON.stringify(ex.coachingCues)},
    commonMistakes: ${JSON.stringify(ex.commonMistakes)},
    primaryMuscles: ${JSON.stringify(ex.primaryMuscles.length > 0 ? ex.primaryMuscles : ['Chest'])},
    secondaryMuscles: ${JSON.stringify(ex.secondaryMuscles)},
    bodyPart: ${JSON.stringify(ex.category)},
    category: ${JSON.stringify(ex.category)},
    subcategory: ${JSON.stringify(ex.subCategory || ex.category)},
    equipment: ${JSON.stringify(ex.equipment || 'Barbell')},
    movementPattern: ${JSON.stringify(ex.movementPattern || 'Compound')},
    exerciseType: ${JSON.stringify(ex.exerciseType || 'Strength')},
    difficulty: ${JSON.stringify(ex.difficulty as any)},
    mechanics: 'Compound',
    forceType: 'Push',
    planeOfMotion: 'Sagittal',
    laterality: 'Bilateral',
    isCompound: true,
    isIsolation: false,
    isUnilateral: false,
    imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600',
    gifUrl: '',
    videoUrl: '',
    thumbnailUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=200',
    variations: [],
    progressions: [],
    regressions: [],
    alternativeExercises: [],
    source: 'Alpha X Gym Database',
    sourceUrl: 'https://alphaxgym.com/exercises',
    license: 'Proprietary',
    licenseAuthor: 'Alpha X Gym Head Coach',
    isImported: false,
    isCustom: false,
    isActive: true,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  },\n`;
}

tsContent += `];\n`;

fs.writeFileSync(seedPath, tsContent, 'utf8');
console.log(`Updated ${seedPath} with ${parsedExercises.length} exercises!`);

import * as fs from 'fs';
import * as path from 'path';
import { INITIAL_EXERCISE_CATALOG } from './modules/exercise/exercise.seed';

const catalogPath = path.resolve(__dirname, '../../apps/mobile/lib/features/exercise/data/default_exercise_catalog.dart');
const existingCatalogContent = fs.readFileSync(catalogPath, 'utf8');

// Read existing exercise IDs
const existingIds = new Set<string>();
const idMatches = existingCatalogContent.matchAll(/id:\s*'([^']+)'/g);
for (const m of idMatches) {
  existingIds.add(m[1]);
}

console.log(`Found ${existingIds.size} existing exercise IDs in default_exercise_catalog.dart`);

const toAdd = INITIAL_EXERCISE_CATALOG.filter((ex) => !existingIds.has(ex.id));
console.log(`Adding ${toAdd.length} new exercises to mobile catalog...`);

function escapeStr(s: string): string {
  return (s || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, ' ');
}

function formatDartList(items: string[]): string {
  if (!items || items.length === 0) return 'const []';
  return `[\n` + items.map((i) => `      '${escapeStr(i)}',`).join('\n') + `\n    ]`;
}

function muscleToDartEnum(muscle: string): string {
  const clean = muscle.replace(/[^a-zA-Z]/g, '').toLowerCase();
  const map: Record<string, string> = {
    chest: 'MuscleGroup.midChest',
    midchest: 'MuscleGroup.midChest',
    upperchest: 'MuscleGroup.upperChest',
    lowerchest: 'MuscleGroup.lowerChest',
    back: 'MuscleGroup.lats',
    lats: 'MuscleGroup.lats',
    upperlats: 'MuscleGroup.lats',
    midback: 'MuscleGroup.rhomboids',
    upperback: 'MuscleGroup.rhomboids',
    lowerback: 'MuscleGroup.lowerBack',
    rhomboids: 'MuscleGroup.rhomboids',
    traps: 'MuscleGroup.traps',
    trapezius: 'MuscleGroup.traps',
    shoulders: 'MuscleGroup.shoulders',
    frontdelts: 'MuscleGroup.frontDelts',
    sidedelts: 'MuscleGroup.sideDelts',
    reardelts: 'MuscleGroup.rearDelts',
    rotatorcuff: 'MuscleGroup.shoulders',
    biceps: 'MuscleGroup.biceps',
    brachialis: 'MuscleGroup.biceps',
    brachioradialis: 'MuscleGroup.forearms',
    triceps: 'MuscleGroup.triceps',
    forearms: 'MuscleGroup.forearms',
    quads: 'MuscleGroup.quads',
    quadriceps: 'MuscleGroup.quads',
    hamstrings: 'MuscleGroup.hamstrings',
    glutes: 'MuscleGroup.glutes',
    glutemedius: 'MuscleGroup.glutes',
    calves: 'MuscleGroup.calves',
    gastrocnemius: 'MuscleGroup.calves',
    soleus: 'MuscleGroup.calves',
    tibialis: 'MuscleGroup.calves',
    tibialisanterior: 'MuscleGroup.calves',
    core: 'MuscleGroup.coreAbs',
    coreabs: 'MuscleGroup.coreAbs',
    abs: 'MuscleGroup.coreAbs',
    lowerabs: 'MuscleGroup.coreAbs',
    obliques: 'MuscleGroup.coreAbs',
    hipflexors: 'MuscleGroup.quads',
    adductors: 'MuscleGroup.glutes',
    abductors: 'MuscleGroup.glutes',
    fullbody: 'MuscleGroup.fullBody',
    legs: 'MuscleGroup.quads',
  };
  return map[clean] || 'MuscleGroup.fullBody';
}

function formatDartMuscles(muscles: string[]): string {
  if (!muscles || muscles.length === 0) return '[MuscleGroup.fullBody]';
  const mapped = muscles.map(muscleToDartEnum);
  return `[${[...new Set(mapped)].join(', ')}]`;
}

function exerciseToDart(ex: any): string {
  return `  Exercise(
    id: '${ex.id}',
    name: '${escapeStr(ex.name)}',
    displayName: '${escapeStr(ex.name)}',
    description: '${escapeStr(ex.description)}',
    category: '${escapeStr(ex.category)}',
    subCategory: '${escapeStr(ex.subcategory || ex.category)}',
    primaryMuscles: ${formatDartMuscles(ex.primaryMuscles)},
    secondaryMuscles: ${formatDartMuscles(ex.secondaryMuscles)},
    equipment: '${escapeStr(ex.equipment)}',
    movementPattern: '${escapeStr(ex.movementPattern)}',
    difficulty: '${ex.difficulty || 'Intermediate'}',
    exerciseType: '${escapeStr(ex.exerciseType || 'Strength')}',
    setupInstructions: ${formatDartList(ex.instructions?.slice(0, 3) || [])},
    executionSteps: ${formatDartList(ex.instructions?.slice(3) || ex.instructions || [])},
    coachingCues: ${formatDartList(ex.coachingCues || [])},
    commonMistakes: ${formatDartList(ex.commonMistakes || [])},
    approvedAlternativeIds: const [],
    defaultTrainerNote: '${escapeStr(ex.defaultTrainerNote || 'Focus on controlled eccentric phase and full active range of motion.')}',
    videoUrl: '',
    thumbnailUrl: '',
    isActive: true,
    tags: ${formatDartList(ex.aliases || [ex.name.toLowerCase()])},
  ),`;
}

if (toAdd.length > 0) {
  const dartCodeBlocks = toAdd.map(exerciseToDart).join('\n');
  const lastBracketIndex = existingCatalogContent.lastIndexOf('];');
  if (lastBracketIndex === -1) {
    throw new Error('Could not find closing ]; in catalog');
  }

  const updatedCatalog =
    existingCatalogContent.substring(0, lastBracketIndex) +
    dartCodeBlocks +
    '\n];\n';

  const newTotal = existingIds.size + toAdd.length;
  const finalCatalog = updatedCatalog.replace(
    /\/\/ Total unique exercises: \d+/,
    `// Total unique exercises: ${newTotal}`
  );

  fs.writeFileSync(catalogPath, finalCatalog, 'utf8');
  console.log(`✔ Successfully updated default_exercise_catalog.dart with ${newTotal} total exercises!`);
} else {
  console.log('Mobile catalog is already up to date with all exercises!');
}

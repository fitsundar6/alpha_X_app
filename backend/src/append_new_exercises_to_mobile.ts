import * as fs from 'fs';
import * as path from 'path';
import { ALL_NEW_EXERCISES, ExerciseEntry } from './build_full_expanded_exercises';

const catalogPath = path.resolve(__dirname, '../../apps/mobile/lib/features/exercise/data/default_exercise_catalog.dart');
const existingCatalogContent = fs.readFileSync(catalogPath, 'utf8');

// Read existing exercise IDs
const existingIds = new Set<string>();
const idMatches = existingCatalogContent.matchAll(/id:\s*'([^']+)'/g);
for (const m of idMatches) {
  existingIds.add(m[1]);
}

console.log(`Found ${existingIds.size} existing exercise IDs in default_exercise_catalog.dart`);

// Filter out any duplicates
const toAdd = ALL_NEW_EXERCISES.filter((ex) => !existingIds.has(ex.id));
console.log(`Adding ${toAdd.length} new exercises (filtered from ${ALL_NEW_EXERCISES.length})`);

function escapeStr(s: string): string {
  return s.replace(/'/g, "\\'");
}

function formatDartList(items: string[]): string {
  return `[\n` + items.map((i) => `      '${escapeStr(i)}',`).join('\n') + `\n    ]`;
}

function formatDartEnumList(enums: string[]): string {
  return `[${enums.join(', ')}]`;
}

function exerciseToDart(ex: ExerciseEntry): string {
  return `  Exercise(
    id: '${ex.id}',
    name: '${escapeStr(ex.name)}',
    displayName: '${escapeStr(ex.name)}',
    description: '${escapeStr(ex.description)}',
    category: '${escapeStr(ex.category)}',
    subCategory: '${escapeStr(ex.subcategory)}',
    primaryMuscles: ${formatDartEnumList(ex.primaryMuscles)},
    secondaryMuscles: ${formatDartEnumList(ex.secondaryMuscles)},
    equipment: '${escapeStr(ex.equipment)}',
    movementPattern: '${escapeStr(ex.movementPattern)}',
    difficulty: '${ex.difficulty}',
    exerciseType: '${escapeStr(ex.exerciseType)}',
    setupInstructions: ${formatDartList(ex.setupInstructions)},
    executionSteps: ${formatDartList(ex.executionSteps)},
    coachingCues: ${formatDartList(ex.coachingCues)},
    commonMistakes: ${formatDartList(ex.commonMistakes)},
    approvedAlternativeIds: const [],
    defaultTrainerNote: '${escapeStr(ex.defaultTrainerNote)}',
    videoUrl: '',
    thumbnailUrl: '',
    isActive: true,
    tags: ${formatDartList(ex.tags)},
  ),`;
}

// Generate the Dart code block to insert
const dartCodeBlocks = toAdd.map(exerciseToDart).join('\n');

// Replace the closing ]; with the new exercises followed by ];
const lastBracketIndex = existingCatalogContent.lastIndexOf('];');
if (lastBracketIndex === -1) {
  throw new Error('Could not find closing ]; in catalog');
}

const updatedCatalog =
  existingCatalogContent.substring(0, lastBracketIndex) +
  dartCodeBlocks +
  '\n];\n';

// Update the header count
const newTotal = existingIds.size + toAdd.length;
const finalCatalog = updatedCatalog.replace(
  /\/\/ Total unique exercises: \d+/,
  `// Total unique exercises: ${newTotal}`
);

fs.writeFileSync(catalogPath, finalCatalog, 'utf8');
console.log(`Successfully updated default_exercise_catalog.dart with ${newTotal} total exercises!`);

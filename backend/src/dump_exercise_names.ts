import * as fs from 'fs';

const filePath = '../apps/mobile/lib/features/exercise/data/default_exercise_catalog.dart';
const content = fs.readFileSync(filePath, 'utf8');

const regex = /Exercise\s*\(\s*id:\s*['"]([^'"]+)['"],\s*name:\s*['"]([^'"]+)['"],/g;
let match;
const existingIds = new Set<string>();
const existingNames = new Set<string>();

while ((match = regex.exec(content)) !== null) {
  existingIds.add(match[1]);
  existingNames.add(match[2].toLowerCase());
}

console.log('Total existing:', existingIds.size);
fs.writeFileSync('src/existing_exercise_names.json', JSON.stringify(Array.from(existingNames), null, 2));
console.log('Wrote existing_exercise_names.json');

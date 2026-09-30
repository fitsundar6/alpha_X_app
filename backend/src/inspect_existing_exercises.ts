import * as fs from 'fs';

const filePath = '../apps/mobile/lib/features/exercise/data/default_exercise_catalog.dart';
const content = fs.readFileSync(filePath, 'utf8');

const regex = /Exercise\s*\(\s*id:\s*['"]([^'"]+)['"],\s*name:\s*['"]([^'"]+)['"],/g;
let match;
const exercises: { id: string; name: string }[] = [];

while ((match = regex.exec(content)) !== null) {
  exercises.push({ id: match[1], name: match[2] });
}

console.log('Total parsed exercises from default_exercise_catalog.dart:', exercises.length);
console.log('Sample first 10:', exercises.slice(0, 10));
console.log('Sample last 10:', exercises.slice(-10));

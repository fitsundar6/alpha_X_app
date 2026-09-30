import * as fs from 'fs';
import * as path from 'path';
import { INITIAL_FOOD_CATALOG } from './modules/food/food.seed';

const mobileFoodDbPath = path.resolve(__dirname, '../../apps/mobile/lib/features/macro_planner/data/food_database.dart');

function escapeStr(s: string): string {
  return s.replace(/'/g, "\\'");
}

let dartContent = `import '../domain/models/food_item.dart';

/// Predefined standard nutritional database for Alpha X Gym athletes
/// Backed by USDA FoodData Central and Indian Food Composition Tables
class FoodDatabase {
  static final List<FoodItem> defaultFoods = [
`;

for (const f of INITIAL_FOOD_CATALOG) {
  dartContent += `    const FoodItem(
      id: '${f.id}',
      name: '${escapeStr(f.name)}',
      servingSize: ${f.servingSize},
      servingUnit: '${f.servingUnit}',
      calories: ${f.calories}.0,
      protein: ${f.protein},
      carbs: ${f.carbohydrates},
      fat: ${f.fat},
      fiber: ${f.fiber},
      sugar: ${f.sugar || 0.0},
      sodium: ${f.sodium || 0.0},
      category: '${escapeStr(f.category)}',
      source: '${f.source}',
      sourceId: ${f.sourceId ? `'${f.sourceId}'` : 'null'},
      isCustom: false,
      isPublic: true,
      isVerified: true,
      status: 'APPROVED',
    ),
`;
}

dartContent += `  ];
}
`;

fs.writeFileSync(mobileFoodDbPath, dartContent, 'utf8');
console.log(`Updated ${mobileFoodDbPath} with ${INITIAL_FOOD_CATALOG.length} verified default foods!`);

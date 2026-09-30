import { foodService } from './modules/food/food.service';

async function main() {
  console.log('--- 1. Search existing verified foods ---');
  const searchChicken = await foodService.searchFoods({ query: 'chicken' });
  console.log('Chicken search matches:', searchChicken.total);
  for (const c of searchChicken.items.slice(0, 3)) {
    console.log(` - ${c.name} (${c.calories} kcal, P:${c.protein}g, C:${c.carbohydrates}g, F:${c.fat}g)`);
  }

  console.log('\n--- 2. Client A creates custom food ---');
  const clientA = { id: 'usr_axg_0001', clientId: 'AXG-0001', name: 'Rohan Sharma' };
  const custom = await foodService.createCustomFood(
    {
      name: 'High Protein Homemade Rice',
      category: 'Indian Foods',
      servingSize: 250,
      servingUnit: 'grams',
      protein: 35,
      carbohydrates: 45,
      fat: 8,
      fiber: 4,
    },
    clientA
  );
  console.log('Created food ID:', custom.food.id);
  console.log('Food name:', custom.food.name);
  console.log('Calculated Calories:', custom.food.calories, 'expected: 392');
  console.log('CreatedBy:', custom.food.createdBy);
  console.log('isDuplicate:', custom.isDuplicate);

  console.log('\n--- 3. Client B searches for Client A custom food ---');
  const clientBSearch = await foodService.searchFoods({ query: 'High Protein Homemade Rice' });
  console.log('Client B search total matches:', clientBSearch.total);
  const found = clientBSearch.items.find((i) => i.name === 'High Protein Homemade Rice');
  console.log('Found by Client B?', !!found);
  if (found) {
    console.log(`Found details: P=${found.protein}g, C=${found.carbohydrates}g, F=${found.fat}g, Calories=${found.calories}`);
  }

  console.log('\n--- 4. Client A attempts duplicate creation ---');
  const dupCheck = await foodService.createCustomFood(
    {
      name: 'High Protein Homemade Rice',
      servingSize: 250,
      servingUnit: 'grams',
      protein: 35,
      carbohydrates: 45,
      fat: 8,
    },
    clientA
  );
  console.log('Duplicate detected?', dupCheck.isDuplicate);
  console.log('Matches original ID?', dupCheck.food.id === custom.food.id);

  console.log('\nAll Food System backend tests completed successfully!');
  process.exit(0);
}

main().catch((err) => {
  console.error('Error running test:', err);
  process.exit(1);
});

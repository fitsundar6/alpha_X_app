import { INITIAL_FOOD_CATALOG } from './modules/food/food.seed';

const requestedFoods = [
  // PROTEIN
  'Chicken breast', 'Chicken thigh', 'Chicken leg', 'Turkey', 'Eggs', 'Egg whites',
  'Lean beef', 'Beef', 'Lamb', 'Pork', 'Fish', 'Tuna', 'Salmon', 'Sardines', 'Mackerel',
  'Prawns', 'Shrimp', 'Paneer', 'Low-fat paneer', 'Tofu', 'Tempeh', 'Soy chunks',
  'Greek yogurt', 'Curd', 'Milk', 'Whey protein', 'Cottage cheese',

  // RICE
  'White rice', 'Brown rice', 'Red rice', 'Basmati rice', 'Cooked rice', 'Raw rice',

  // SOUTH INDIAN
  'Idli', 'Dosa', 'Plain dosa', 'Masala dosa', 'Ragi dosa', 'Adai', 'Pongal',
  'Upma', 'Appam', 'Idiyappam', 'Puttu', 'Chapati', 'Parotta', 'Roti',
  'Curd rice', 'Lemon rice', 'Tomato rice', 'Sambar', 'Rasam',

  // DAL / LEGUMES
  'Toor dal', 'Moong dal', 'Masoor dal', 'Urad dal', 'Chana dal', 'Chickpeas',
  'Rajma', 'Black beans', 'Green gram', 'Sprouted green gram', 'Peanuts',

  // VEGETABLES
  'Potato', 'Sweet potato', 'Carrot', 'Beans', 'Beetroot', 'Broccoli', 'Cauliflower',
  'Spinach', 'Cabbage', 'Capsicum', 'Tomato', 'Cucumber', 'Onion', 'Brinjal',
  'Ladies finger', 'Pumpkin', 'Bottle gourd', 'Bitter gourd', 'Drumstick',
  'Green peas', 'Mushroom', 'Corn',

  // FRUITS
  'Banana', 'Apple', 'Orange', 'Grapes', 'Mango', 'Papaya', 'Pineapple',
  'Watermelon', 'Muskmelon', 'Guava', 'Pomegranate', 'Kiwi', 'Strawberry',
  'Blueberry', 'Dates', 'Fig', 'Coconut', 'Avocado',

  // NUTS / SEEDS
  'Almond', 'Cashew', 'Walnut', 'Pistachio', 'Peanut', 'Peanut butter',
  'Almond butter', 'Chia seeds', 'Flax seeds', 'Pumpkin seeds', 'Sunflower seeds', 'Sesame seeds',

  // COMMON FITNESS
  'Oats', 'Whole wheat bread', 'Whole wheat roti'
];

const existingFoodNames = INITIAL_FOOD_CATALOG.map(f => f.name.toLowerCase());
const missingFoods: string[] = [];

for (const req of requestedFoods) {
  const norm = req.toLowerCase();
  const found = existingFoodNames.some(n => n.includes(norm) || norm.includes(n));
  if (!found) {
    missingFoods.push(req);
  }
}

console.log('Total requested foods checked:', requestedFoods.length);
console.log('Missing foods count:', missingFoods.length);
console.log('Missing foods:', missingFoods);

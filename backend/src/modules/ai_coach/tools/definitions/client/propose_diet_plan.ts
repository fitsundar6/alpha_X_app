/**
 * Alpha X AI — Tool: propose_diet_plan
 * Phase 7 — AI Plan Proposal Engine
 *
 * The AI calls this tool to save a complete, structured proposed diet plan for admin review.
 * The plan is NEVER assigned to the client until the admin explicitly approves it.
 */

import { ToolDefinition, ToolPermission, ToolExecutionContext } from '../../tool.types';
import { prisma } from '../../../../../config/prisma';
import { clientDataService } from '../client/client_data.service';

export interface ProposeDietPlanInput {
  clientIdentifier: string;
  planName?: string;              // e.g. "Ajay — High-Protein Fat Loss Plan"
  planTitle?: string;             // Alias for planName
  planKind?: 'DIET_PLAN' | 'MACRO_ONLY' | string;
  reason: string;                 // Why this diet suits the client based on assessment
  summary: string;                // 1-2 sentence overview for admin
  dailyCalories: number;
  protein: number;                // grams
  carbohydrates: number;          // grams
  fat: number;                    // grams
  fiber?: number;                 // grams
  waterTargetLiters?: number;
  meals?: Array<{
    mealType?: string;            // "Breakfast", "Lunch", "Snacks", "Dinner"
    name?: string;
    timing?: string;              // "8:00 AM", "1:00 PM", "4:30 PM", "8:00 PM"
    notes?: string;
    foods?: Array<{
      foodId?: string;
      foodName?: string;
      name?: string;
      quantity: number;
      unit?: string;
      calories?: number;
      protein?: number;
      carbs?: number;
      carbohydrates?: number;
      fat?: number;
      fiber?: number;
      notes?: string;
      substitutions?: string;
    }>;
    items?: Array<{
      foodId?: string;
      foodName?: string;
      name?: string;
      quantity: number;
      unit?: string;
      calories?: number;
      protein?: number;
      carbs?: number;
      carbohydrates?: number;
      fat?: number;
      fiber?: number;
      notes?: string;
      substitutions?: string;
    }>;
  }>;
  mealSuggestions?: Array<{
    mealName: string;
    timing?: string;
    targetCalories: number;
    targetProtein: number;
    foods: Array<string | any>;
  }>;
  notes?: string;
}

/**
 * Estimates macronutrients based on food name and portion if nutritional values are missing or zero.
 */
function estimateFoodNutrition(
  foodName: string,
  quantity: number,
  unit: string,
  providedCalories?: number,
  providedProtein?: number,
  providedCarbs?: number,
  providedFat?: number,
  providedFiber?: number,
): { calories: number; protein: number; carbs: number; fat: number; fiber: number } {
  let cal = Number(providedCalories) || 0;
  let pro = Number(providedProtein) || 0;
  let crb = Number(providedCarbs) || 0;
  let ft = Number(providedFat) || 0;
  let fib = Number(providedFiber) || 0;

  // If all macros and calories are provided, return as is
  if (cal > 0 && (pro > 0 || crb > 0 || ft > 0)) {
    return {
      calories: Math.round(cal),
      protein: Math.round(pro * 10) / 10,
      carbs: Math.round(crb * 10) / 10,
      fat: Math.round(ft * 10) / 10,
      fiber: Math.round(fib * 10) / 10,
    };
  }

  // Calculate calories from macros if calories is 0
  if (cal === 0 && (pro > 0 || crb > 0 || ft > 0)) {
    cal = Math.round((pro * 4) + (crb * 4) + (ft * 9));
    return {
      calories: cal,
      protein: Math.round(pro * 10) / 10,
      carbs: Math.round(crb * 10) / 10,
      fat: Math.round(ft * 10) / 10,
      fiber: Math.round(fib * 10) / 10,
    };
  }

  // If macros are missing, estimate per 100g base or per piece
  const lower = foodName.toLowerCase();
  const cleanUnit = (unit || 'g').toLowerCase();
  let base100g = { cal: 150, pro: 10, crb: 15, fat: 5, fib: 2 };

  if (lower.includes('egg white')) {
    base100g = { cal: 52, pro: 11, crb: 0.7, fat: 0.2, fib: 0 };
  } else if (lower.includes('egg')) {
    base100g = cleanUnit.includes('piece') || cleanUnit.includes('egg')
      ? { cal: 74, pro: 6.3, crb: 0.4, fat: 5.0, fib: 0 }
      : { cal: 143, pro: 13, crb: 0.8, fat: 9.5, fib: 0 };
  } else if (lower.includes('chicken breast') || lower.includes('poultry')) {
    base100g = { cal: 165, pro: 31, crb: 0, fat: 3.6, fib: 0 };
  } else if (lower.includes('chicken') || lower.includes('turkey')) {
    base100g = { cal: 190, pro: 27, crb: 0, fat: 8, fib: 0 };
  } else if (lower.includes('fish') || lower.includes('salmon') || lower.includes('tuna')) {
    base100g = { cal: 180, pro: 25, crb: 0, fat: 8, fib: 0 };
  } else if (lower.includes('paneer') || lower.includes('cottage cheese')) {
    base100g = { cal: 265, pro: 18, crb: 3, fat: 20, fib: 0 };
  } else if (lower.includes('tofu') || lower.includes('soya') || lower.includes('soy')) {
    base100g = { cal: 120, pro: 15, crb: 3, fat: 5, fib: 1.5 };
  } else if (lower.includes('whey') || lower.includes('protein powder') || lower.includes('isolate')) {
    base100g = { cal: 380, pro: 80, crb: 5, fat: 4, fib: 1 };
  } else if (lower.includes('oat') || lower.includes('oatmeal')) {
    base100g = { cal: 389, pro: 16.9, crb: 66.3, fat: 6.9, fib: 10.6 };
  } else if (lower.includes('rice') || lower.includes('quinoa')) {
    base100g = { cal: 130, pro: 2.7, crb: 28, fat: 0.3, fib: 0.4 };
  } else if (lower.includes('roti') || lower.includes('chapati') || lower.includes('bread')) {
    base100g = cleanUnit.includes('piece') || cleanUnit.includes('slice')
      ? { cal: 100, pro: 3.5, crb: 20, fat: 1.5, fib: 2.5 }
      : { cal: 260, pro: 9, crb: 50, fat: 3.5, fib: 6 };
  } else if (lower.includes('dal') || lower.includes('lentil') || lower.includes('chickpea')) {
    base100g = { cal: 140, pro: 9, crb: 20, fat: 2.5, fib: 5 };
  } else if (lower.includes('curd') || lower.includes('yogurt') || lower.includes('greek yogurt')) {
    base100g = { cal: 97, pro: 9, crb: 4, fat: 5, fib: 0 };
  } else if (lower.includes('milk')) {
    base100g = { cal: 60, pro: 3.2, crb: 4.8, fat: 3.2, fib: 0 };
  } else if (lower.includes('almond') || lower.includes('walnut') || lower.includes('peanut') || lower.includes('nut')) {
    base100g = { cal: 580, pro: 21, crb: 20, fat: 50, fib: 11 };
  } else if (lower.includes('oil') || lower.includes('ghee') || lower.includes('butter')) {
    base100g = { cal: 884, pro: 0, crb: 0, fat: 100, fib: 0 };
  } else if (lower.includes('banana') || lower.includes('apple') || lower.includes('fruit')) {
    base100g = { cal: 89, pro: 1.1, crb: 23, fat: 0.3, fib: 2.6 };
  } else if (lower.includes('spinach') || lower.includes('broccoli') || lower.includes('salad') || lower.includes('vegetable')) {
    base100g = { cal: 35, pro: 2.5, crb: 6, fat: 0.5, fib: 3 };
  }

  // Calculate multiplier
  let mult = 1.0;
  if (
    cleanUnit === 'piece' || cleanUnit === 'pieces' ||
    cleanUnit === 'slice' || cleanUnit === 'slices' ||
    cleanUnit === 'egg' || cleanUnit === 'eggs' ||
    cleanUnit === 'scoop' || cleanUnit === 'scoops'
  ) {
    mult = quantity;
  } else if (cleanUnit === 'kg' || cleanUnit === 'l' || cleanUnit === 'liter' || cleanUnit === 'liters') {
    mult = (quantity * 1000) / 100;
  } else if (cleanUnit === 'tbsp') {
    mult = (quantity * 15) / 100;
  } else if (cleanUnit === 'tsp') {
    mult = (quantity * 5) / 100;
  } else {
    // grams or ml
    mult = quantity / 100;
  }

  // If caller provided total calories for the item, scale base macros to match
  if (cal > 0) {
    const defaultCal = Math.max(1, base100g.cal * mult);
    const ratio = cal / defaultCal;
    pro = Math.round(base100g.pro * mult * ratio * 10) / 10;
    crb = Math.round(base100g.crb * mult * ratio * 10) / 10;
    ft = Math.round(base100g.fat * mult * ratio * 10) / 10;
    fib = Math.round(base100g.fib * mult * ratio * 10) / 10;
  } else {
    cal = Math.round(base100g.cal * mult);
    pro = Math.round(base100g.pro * mult * 10) / 10;
    crb = Math.round(base100g.crb * mult * 10) / 10;
    ft = Math.round(base100g.fat * mult * 10) / 10;
    fib = Math.round(base100g.fib * mult * 10) / 10;
  }

  return { calories: Math.round(cal), protein: pro, carbs: crb, fat: ft, fiber: fib };
}

export const proposeDietPlanTool: ToolDefinition<ProposeDietPlanInput> = {
  name: 'propose_diet_plan',
  description:
    'Saves a complete AI-generated personalized diet plan or macro-only plan as a PENDING proposal for admin review and approval. ' +
    'Call this after reading the client profile, current weight, height, goals, dietary preferences, and activity level. ' +
    'The plan is NOT assigned to the client until the admin approves it. ' +
    'Provide daily macro targets (calories, protein, carbs, fat, fiber, water). For a full diet plan, provide structured meals with timings and food items in grams. For a macro-only plan, set planKind to "MACRO_ONLY" without meals.',
  category: 'PROPOSE',
  permission: ToolPermission.PROPOSE_PLAN,
  inputSchema: {
    type: 'object',
    properties: {
      clientIdentifier: {
        type: 'string',
        description: 'Client name, AXG-XXXX ID, or UUID',
        minLength: 1,
        maxLength: 100,
      },
      planName: {
        type: 'string',
        description: 'Short descriptive name, e.g. "Ajay — High-Protein Fat Loss Plan"',
        maxLength: 120,
      },
      planTitle: {
        type: 'string',
        description: 'Alternative title parameter',
        maxLength: 120,
      },
      planKind: {
        type: 'string',
        enum: ['DIET_PLAN', 'MACRO_ONLY'],
        description: 'Set to "MACRO_ONLY" for daily calorie/macro targets without structured meals, or "DIET_PLAN" for a full meal plan',
      },
      reason: {
        type: 'string',
        description: 'Evidence-based reason this diet suits the client based on assessment data, weight, and goals',
        minLength: 10,
        maxLength: 800,
      },
      summary: {
        type: 'string',
        description: '1-2 sentence plain-language overview for the admin including macro totals',
        minLength: 10,
        maxLength: 300,
      },
      dailyCalories: {
        type: 'number',
        description: 'Total daily calorie target',
        minimum: 800,
        maximum: 6000,
      },
      protein: {
        type: 'number',
        description: 'Daily protein target in grams',
        minimum: 40,
        maximum: 500,
      },
      carbohydrates: {
        type: 'number',
        description: 'Daily carbohydrate target in grams',
        minimum: 0,
        maximum: 1000,
      },
      fat: {
        type: 'number',
        description: 'Daily fat target in grams',
        minimum: 20,
        maximum: 400,
      },
      fiber: {
        type: 'number',
        description: 'Daily fiber target in grams',
        minimum: 10,
        maximum: 80,
      },
      waterTargetLiters: {
        type: 'number',
        description: 'Daily water intake target in liters',
        minimum: 1,
        maximum: 6,
      },
      meals: {
        type: 'array',
        description: 'Complete structured meal plan (Breakfast, Lunch, Snacks, Dinner). REQUIRED when creating a full diet plan (DIET_PLAN). Each meal MUST have mealType, timing, and non-empty foods with specific portion quantities and macros. ONLY omit or leave empty for MACRO_ONLY plans.',
        items: {
          type: 'object',
          required: ['mealType', 'foods'],
          properties: {
            mealType: { type: 'string', description: 'Meal name, e.g. Breakfast, Lunch, Snacks, Dinner' },
            name: { type: 'string', description: 'Alternative name for meal' },
            timing: { type: 'string', description: 'Timing of meal, e.g. "8:00 AM", "1:00 PM"' },
            notes: { type: 'string', description: 'Optional meal preparation notes or timing guidance' },
            foods: {
              type: 'array',
              description: 'List of foods in this meal with quantities and nutritional values',
              items: {
                type: 'object',
                required: ['foodName', 'quantity', 'unit'],
                properties: {
                  foodId: { type: 'string' },
                  foodName: { type: 'string', description: 'Name of the food item' },
                  name: { type: 'string', description: 'Alternative food name' },
                  quantity: { type: 'number', description: 'Portion quantity (e.g. 150, 2, 30)' },
                  unit: { type: 'string', description: 'Unit of measure, e.g. g, ml, piece, scoop, serving' },
                  calories: { type: 'number', description: 'Calories for this portion' },
                  protein: { type: 'number', description: 'Protein in grams' },
                  carbs: { type: 'number', description: 'Carbohydrates in grams' },
                  carbohydrates: { type: 'number', description: 'Carbohydrates in grams' },
                  fat: { type: 'number', description: 'Fat in grams' },
                  fiber: { type: 'number', description: 'Fiber in grams' },
                  notes: { type: 'string', description: 'Optional cooking/preparation note' },
                  substitutions: { type: 'string', description: 'Optional acceptable food substitutions' },
                },
              },
            },
            items: {
              type: 'array',
              description: 'Alternative alias for foods array',
              items: {
                type: 'object',
                required: ['foodName', 'quantity', 'unit'],
                properties: {
                  foodId: { type: 'string' },
                  foodName: { type: 'string' },
                  name: { type: 'string' },
                  quantity: { type: 'number' },
                  unit: { type: 'string' },
                  calories: { type: 'number' },
                  protein: { type: 'number' },
                  carbs: { type: 'number' },
                  carbohydrates: { type: 'number' },
                  fat: { type: 'number' },
                  fiber: { type: 'number' },
                  notes: { type: 'string' },
                  substitutions: { type: 'string' },
                },
              },
            },
          },
        } as any,
      },
      mealSuggestions: {
        type: 'array',
        description: 'Optional suggested meals per day',
        items: {
          type: 'object',
          properties: {
            mealName: { type: 'string' },
            timing: { type: 'string' },
            targetCalories: { type: 'number' },
            targetProtein: { type: 'number' },
            foods: {
              type: 'array',
              items: { type: 'string' },
            },
          },
        } as any,
      },
      notes: {
        type: 'string',
        description: 'Optional coaching notes or dietary restrictions to highlight',
        maxLength: 500,
      },
    },
    required: ['clientIdentifier', 'reason', 'summary', 'dailyCalories', 'protein', 'carbohydrates', 'fat'],
  },
  handler: async (args: ProposeDietPlanInput, context: ToolExecutionContext) => {
    // 1. Validate required fields
    if (!args.clientIdentifier || !args.clientIdentifier.trim()) {
      return { success: false, error: 'VALIDATION_ERROR', message: 'Client identifier is required' };
    }

    if (args.planName !== undefined && args.planName.trim().length === 0 && (!args.planTitle || args.planTitle.trim().length === 0)) {
      return { success: false, error: 'VALIDATION_ERROR', message: 'Plan name is required' };
    }

    if (!args.reason || !args.reason.trim()) {
      return { success: false, error: 'VALIDATION_ERROR', message: 'Rationale explaining why this plan suits the client is required' };
    }
    if (!args.summary || !args.summary.trim()) {
      return { success: false, error: 'VALIDATION_ERROR', message: 'Summary overview is required' };
    }
    const dailyCalories = Number(args.dailyCalories);
    const protein = Number(args.protein);
    const carbohydrates = Number(args.carbohydrates);
    const fat = Number(args.fat);
    if (!dailyCalories || dailyCalories <= 0 || !protein || protein <= 0 || carbohydrates < 0 || fat < 0) {
      return { success: false, error: 'VALIDATION_ERROR', message: 'Valid positive daily calories and macronutrients are required' };
    }

    // 2. Resolve client
    const resolved = await clientDataService.resolveClient(args.clientIdentifier);
    if (resolved.status !== 'FOUND' || !resolved.client) {
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: resolved.status === 'AMBIGUOUS'
          ? 'MULTIPLE_CLIENTS_FOUND — please specify the exact client AXG ID'
          : 'CLIENT_NOT_FOUND',
        message: resolved.message || `Client "${args.clientIdentifier}" not found in Alpha X database`,
      };
    }

    const { profileId, clientId, name } = resolved.client;

    // Read full client profile for dietary safety & restrictions
    const clientProfile = await prisma.clientProfile.findUnique({
      where: { id: profileId },
      select: {
        weightKg: true,
        heightCm: true,
        age: true,
        gender: true,
        primaryGoal: true,
        fitnessLevel: true,
        activityLevel: true,
        adminNotes: true,
        trainingPreferences: true,
      },
    });

    const fiber = Number(args.fiber) || 30;
    const water = Number(args.waterTargetLiters) || 3.5;

    // Clear separation between Full Diet Plan and Macro-Only Plan
    const isExplicitMacroOnly = args.planKind === 'MACRO_ONLY' ||
      ((args.planName || args.planTitle || '').toLowerCase().includes('macro-only') && args.planKind !== 'DIET_PLAN');

    const defaultTimings = ['8:00 AM', '1:00 PM', '4:30 PM', '8:00 PM'];
    let normalizedMeals: any[] = [];

    if (!isExplicitMacroOnly) {
      // FULL DIET PLAN VALIDATION: Must contain actual structured meals with food items and quantities
      const rawMeals = (Array.isArray(args.meals) && args.meals.length > 0)
        ? args.meals
        : (Array.isArray(args.mealSuggestions) && args.mealSuggestions.length > 0 ? args.mealSuggestions : null);

      if (!rawMeals || rawMeals.length === 0) {
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: 'A Full Diet Plan proposal requires a non-empty list of structured meals with food items, portion quantities, and nutritional values. If only daily calories and macro targets are intended, set planKind to "MACRO_ONLY".',
        };
      }

      if (Array.isArray(args.meals) && args.meals.length > 0) {
        for (let mIdx = 0; mIdx < args.meals.length; mIdx++) {
          const m: any = args.meals[mIdx];
          const mealType = m.mealType || m.name || m.mealName || `Meal ${mIdx + 1}`;
          const timing = m.timing || defaultTimings[mIdx] || '12:00 PM';
          const rawItems = (m.foods || m.items || []) as any[];

          if (!Array.isArray(rawItems) || rawItems.length === 0) {
            return {
              success: false,
              source: 'ALPHA_X_DATABASE',
              error: 'VALIDATION_ERROR',
              message: `Meal "${mealType}" must contain at least one food item with quantity and unit.`,
            };
          }

          const items: any[] = [];
          for (let iIdx = 0; iIdx < rawItems.length; iIdx++) {
            const it: any = rawItems[iIdx];
            const fName = (it.foodName || it.name || '').trim();
            if (!fName) {
              return {
                success: false,
                source: 'ALPHA_X_DATABASE',
                error: 'VALIDATION_ERROR',
                message: `Each food in meal "${mealType}" must have a valid non-empty food name.`,
              };
            }

            const qty = Number(it.quantity);
            if (isNaN(qty) || qty <= 0) {
              return {
                success: false,
                source: 'ALPHA_X_DATABASE',
                error: 'VALIDATION_ERROR',
                message: `Food "${fName}" in meal "${mealType}" has invalid quantity "${it.quantity}". Quantity must be a positive number.`,
              };
            }

            const unit = it.unit || 'g';
            const rawCal = Number(it.calories) || 0;
            const rawPro = Number(it.protein) || 0;
            const rawCrb = Number(it.carbs ?? it.carbohydrates) || 0;
            const rawFt = Number(it.fat) || 0;
            const rawFib = Number(it.fiber) || 0;

            const estimated = estimateFoodNutrition(fName, qty, unit, rawCal, rawPro, rawCrb, rawFt, rawFib);
            const cal = estimated.calories;
            const pro = estimated.protein;
            const crb = estimated.carbs;
            const ft = estimated.fat;
            const fib = estimated.fiber;
            const notes = it.notes || null;
            const subs = it.substitutions || it.substitute || null;

            items.push({
              foodId: it.foodId || `f_custom_${mIdx}_${iIdx}`,
              name: fName,
              foodName: fName,
              quantity: qty,
              unit,
              calories: cal,
              protein: pro,
              carbs: crb,
              carbohydrates: crb,
              fat: ft,
              fiber: fib,
              notes,
              substitutions: subs,
            });
          }

          const mealCalories = Math.round(items.reduce((acc, it) => acc + (it.calories || 0), 0));
          const mealProtein = Math.round(items.reduce((acc, it) => acc + (it.protein || 0), 0) * 10) / 10;
          const mealCarbs = Math.round(items.reduce((acc, it) => acc + (it.carbs || 0), 0) * 10) / 10;
          const mealFat = Math.round(items.reduce((acc, it) => acc + (it.fat || 0), 0) * 10) / 10;
          const mealFiber = Math.round(items.reduce((acc, it) => acc + (it.fiber || 0), 0) * 10) / 10;

          normalizedMeals.push({
            mealType,
            name: mealType,
            timing,
            notes: m.notes || null,
            calories: mealCalories,
            protein: mealProtein,
            carbs: mealCarbs,
            carbohydrates: mealCarbs,
            fat: mealFat,
            fiber: mealFiber,
            totalCalories: mealCalories,
            totalProtein: mealProtein,
            totalCarbs: mealCarbs,
            totalFat: mealFat,
            foods: items,
            items,
          });
        }
      } else if (Array.isArray(args.mealSuggestions) && args.mealSuggestions.length > 0) {
        // Adapt mealSuggestions into validated structured meals
        for (let mIdx = 0; mIdx < args.mealSuggestions.length; mIdx++) {
          const ms: any = args.mealSuggestions[mIdx];
          const mealType = ms.mealName || ms.name || `Meal ${mIdx + 1}`;
          const timing = ms.timing || defaultTimings[mIdx] || '12:00 PM';
          const rawFoods = Array.isArray(ms.foods) ? ms.foods : [];

          if (rawFoods.length === 0) {
            return {
              success: false,
              source: 'ALPHA_X_DATABASE',
              error: 'VALIDATION_ERROR',
              message: `Meal "${mealType}" must contain at least one food item with quantity.`,
            };
          }

          const items: any[] = [];
          for (let fIdx = 0; fIdx < rawFoods.length; fIdx++) {
            const f: any = rawFoods[fIdx];
            if (typeof f === 'string') {
              const match = f.match(/(\d+)\s*(g|grams?|ml|piece|cup|oz)?/i);
              const qty = match ? parseFloat(match[1]) : 100;
              const unit = match && match[2] ? match[2] : 'g';
              const fName = f.replace(/(\d+)\s*(g|grams?|ml|piece|cup|oz)?/i, '').trim() || f;

              const approxCal = Math.round(Number(ms.targetCalories || 350) / Math.max(1, rawFoods.length));
              const approxPro = Math.round((Number(ms.targetProtein || 25) / Math.max(1, rawFoods.length)) * 10) / 10;

              items.push({
                foodId: `f_sug_${mIdx}_${fIdx}`,
                name: fName,
                foodName: fName,
                quantity: qty,
                unit,
                calories: approxCal,
                protein: approxPro,
                carbs: Math.round((approxCal * 0.4) / 4),
                carbohydrates: Math.round((approxCal * 0.4) / 4),
                fat: Math.round((approxCal * 0.25) / 9),
                fiber: 3,
              });
            } else {
              const fName = f.foodName || f.name || 'Food';
              const qty = Number(f.quantity) || 100;
              const unit = f.unit || 'g';
              const rawCal = Number(f.calories) || 0;
              const rawPro = Number(f.protein) || 0;
              const rawCrb = Number(f.carbs ?? f.carbohydrates) || 0;
              const rawFt = Number(f.fat) || 0;
              const rawFib = Number(f.fiber) || 0;

              const estimated = estimateFoodNutrition(fName, qty, unit, rawCal, rawPro, rawCrb, rawFt, rawFib);
              items.push({
                foodId: f.foodId || `f_sug_${mIdx}_${fIdx}`,
                name: fName,
                foodName: fName,
                quantity: qty,
                unit,
                calories: estimated.calories,
                protein: estimated.protein,
                carbs: estimated.carbs,
                carbohydrates: estimated.carbs,
                fat: estimated.fat,
                fiber: estimated.fiber,
              });
            }
          }

          const mealCalories = Math.round(items.reduce((acc, it) => acc + (it.calories || 0), 0));
          const mealProtein = Math.round(items.reduce((acc, it) => acc + (it.protein || 0), 0) * 10) / 10;
          const mealCarbs = Math.round(items.reduce((acc, it) => acc + (it.carbs || 0), 0) * 10) / 10;
          const mealFat = Math.round(items.reduce((acc, it) => acc + (it.fat || 0), 0) * 10) / 10;

          normalizedMeals.push({
            mealType,
            name: mealType,
            timing,
            notes: ms.notes || null,
            calories: mealCalories,
            protein: mealProtein,
            carbs: mealCarbs,
            carbohydrates: mealCarbs,
            fat: mealFat,
            totalCalories: mealCalories,
            totalProtein: mealProtein,
            totalCarbs: mealCarbs,
            totalFat: mealFat,
            foods: items,
            items,
          });
        }
      }

      // Harmonize meal totals with daily calorie target by proportionally scaling food portions
      const sumMealCalories = normalizedMeals.reduce((acc, m) => acc + (m.calories || 0), 0);
      if (sumMealCalories > 0 && Math.abs(sumMealCalories - dailyCalories) > Math.max(dailyCalories * 0.20, 250)) {
        return {
          success: false,
          source: 'ALPHA_X_DATABASE',
          error: 'VALIDATION_ERROR',
          message: `Total meal calories (${sumMealCalories} kcal) deviate significantly from the daily target (${dailyCalories} kcal). Please provide meals that align with the daily calorie target.`,
        };
      }
      if (sumMealCalories > 0 && Math.abs(sumMealCalories - dailyCalories) > 10) {
        const scale = dailyCalories / sumMealCalories;
        normalizedMeals = normalizedMeals.map((meal) => {
          const scaledFoods = (meal.foods || []).map((food: any) => ({
            ...food,
            quantity: Math.max(1, Math.round(Number(food.quantity) * scale)),
            calories: Math.max(1, Math.round(Number(food.calories) * scale)),
            protein: Math.round(Number(food.protein) * scale * 10) / 10,
            carbs: Math.round(Number(food.carbs ?? food.carbohydrates) * scale * 10) / 10,
            carbohydrates: Math.round(Number(food.carbs ?? food.carbohydrates) * scale * 10) / 10,
            fat: Math.round(Number(food.fat) * scale * 10) / 10,
            fiber: Math.round(Number(food.fiber || 0) * scale * 10) / 10,
          }));
          const mealCalories = Math.round(scaledFoods.reduce((acc: number, it: any) => acc + (it.calories || 0), 0));
          const mealProtein = Math.round(scaledFoods.reduce((acc: number, it: any) => acc + (it.protein || 0), 0) * 10) / 10;
          const mealCarbs = Math.round(scaledFoods.reduce((acc: number, it: any) => acc + (it.carbs || 0), 0) * 10) / 10;
          const mealFat = Math.round(scaledFoods.reduce((acc: number, it: any) => acc + (it.fat || 0), 0) * 10) / 10;
          const mealFiber = Math.round(scaledFoods.reduce((acc: number, it: any) => acc + (it.fiber || 0), 0) * 10) / 10;

          return {
            ...meal,
            calories: mealCalories,
            protein: mealProtein,
            carbs: mealCarbs,
            carbohydrates: mealCarbs,
            fat: mealFat,
            fiber: mealFiber,
            totalCalories: mealCalories,
            totalProtein: mealProtein,
            totalCarbs: mealCarbs,
            totalFat: mealFat,
            foods: scaledFoods,
            items: scaledFoods,
          };
        });
      }
    }

    const resolvedTitle = (args.planName && args.planName.trim()) ||
      (args.planTitle && args.planTitle.trim()) ||
      (isExplicitMacroOnly ? `${name} — Daily Macro Targets (Macro-Only)` : `${name} — Tailored Nutrition Plan`);

    // 4. Construct complete interoperable payload
    const proposedPayload = {
      planKind: isExplicitMacroOnly ? 'MACRO_ONLY' : 'DIET_PLAN',
      isMacroOnly: isExplicitMacroOnly,
      planName: resolvedTitle,
      dailyCalories,
      protein,
      carbohydrates,
      fat,
      fiber,
      waterTargetLiters: water,
      meals: normalizedMeals,
      mealSuggestions: normalizedMeals.map((m) => ({
        mealName: m.mealType,
        timing: m.timing,
        targetCalories: m.foods.reduce((acc: number, f: any) => acc + (f.calories || 0), 0),
        targetProtein: m.foods.reduce((acc: number, f: any) => acc + (f.protein || 0), 0),
        foods: m.foods.map((f: any) => `${f.foodName || f.name} (${f.quantity}${f.unit || 'g'})`),
      })),
      notes: args.notes || (isExplicitMacroOnly
        ? `Daily macro targets for ${name}. Objective: ${clientProfile?.primaryGoal || 'Healthy Lifestyle'}. Flexible dieting protocol with no fixed meal requirements.`
        : `Tailored protocol for ${name}. Objective: ${clientProfile?.primaryGoal || 'Healthy Lifestyle'}.`),
      rationale: args.reason,
      assumptions: `Caloric intake calculated from client bodyweight (${clientProfile?.weightKg || 'baseline'} kg), height (${clientProfile?.heightCm || 'baseline'} cm), and ${clientProfile?.activityLevel || 'moderate'} activity tier.`,
      generatedAt: new Date().toISOString(),
      generatedByAdminId: context.adminId,
    };

    // 5. Safely resolve conversationId to prevent foreign key violations
    let validConversationId: string | null = null;
    if (context.conversationId) {
      const convExists = await prisma.aIConversation.findUnique({
        where: { id: context.conversationId },
        select: { id: true },
      });
      if (convExists) {
        validConversationId = convExists.id;
      }
    }

    // 6. Prevent duplicate proposals caused by retries or repeated tool calls
    let proposal;
    try {
      const existing = await prisma.aIProposal.findFirst({
        where: {
          clientProfileId: profileId,
          proposalType: 'DIET',
          status: 'PENDING',
          ...(validConversationId ? { conversationId: validConversationId } : {}),
        },
        orderBy: { createdAt: 'desc' },
      });

      if (existing) {
        proposal = await prisma.aIProposal.update({
          where: { id: existing.id },
          data: {
            title: resolvedTitle,
            summary: args.summary,
            reason: args.reason,
            proposedDataJson: JSON.stringify(proposedPayload),
            finalDataJson: null,
            status: 'PENDING',
            updatedAt: new Date(),
          },
          select: { id: true, title: true, status: true, createdAt: true },
        });
      } else {
        proposal = await prisma.aIProposal.create({
          data: {
            conversationId: validConversationId,
            clientProfileId: profileId,
            clientId: clientId || null,
            clientName: name,
            proposalType: 'DIET',
            status: 'PENDING',
            title: resolvedTitle,
            summary: args.summary,
            reason: args.reason,
            proposedDataJson: JSON.stringify(proposedPayload),
          },
          select: { id: true, title: true, status: true, createdAt: true },
        });
      }
    } catch (dbError: any) {
      console.error('[propose_diet_plan] Failed to persist AIProposal:', dbError);
      return {
        success: false,
        source: 'ALPHA_X_DATABASE',
        error: 'DATABASE_ERROR',
        message: `Database error while saving proposal: ${dbError?.message || dbError}`,
      };
    }

    return {
      success: true,
      source: 'ALPHA_X_DATABASE',
      message: isExplicitMacroOnly ? 'Macro-only proposal saved for admin review' : 'Diet plan proposal saved for admin review',
      proposalId: proposal.id,
      status: 'PENDING',
      clientName: name,
      planName: resolvedTitle,
      macroSummary: {
        calories: dailyCalories,
        proteinG: protein,
        carbsG: carbohydrates,
        fatG: fat,
        fiberG: fiber,
        waterTargetLiters: water,
      },
      proposal: {
        id: proposal.id,
        clientId: clientId || profileId,
        clientName: name,
        type: 'DIET',
        title: proposal.title,
        status: 'PENDING',
        summary: args.summary,
        reason: args.reason,
        payload: proposedPayload,
      },
      note: 'The admin must approve this proposal before it is assigned to the client. Tell the admin they can review and accept it in Admin Review.',
    };
  },
  enabled: true,
};

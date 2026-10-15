/**
 * Alpha X Gym — Scientific Diet & Macro Personalization Engine
 *
 * Implements Mifflin-St Jeor Energy Estimation, Activity Scaling,
 * and Goal-Specific Macronutrient Partitioning:
 * - Fat Loss: Caloric deficit (~20%), muscle-preserving protein (2.2 g/kg), essential fat, remainder carbs.
 * - Lean Bulk: Controlled surplus (~10%), hyper-trophy protein (2.0 g/kg), moderate fat (25%), high carbs.
 * - Maintenance: Caloric balance (1.00 TDEE), baseline protein (1.8 g/kg), balanced fat & carbs.
 * - Athletic Performance: High-energy performance demand (1.08 TDEE), 1.9 g/kg protein, glycogen-fueling high carbs.
 * - Custom Goal: Preserves coach custom values or custom goal instructions.
 *
 * Strict energy balance validation: 4*Protein + 4*Carbs + 9*Fat ≈ Calories.
 * Incomplete assessment metrics are flagged for admin review.
 */

export interface ClientBiometrics {
  weightKg?: number | string | null;
  heightCm?: number | string | null;
  age?: number | string | null;
  gender?: string | null;
  activityLevel?: string | null;
  trainingDaysPerWeek?: number | string | null;
}

export interface MacroOverrides {
  dailyCalories?: number | string | null;
  protein?: number | string | null;
  carbohydrates?: number | string | null;
  fat?: number | string | null;
  fiber?: number | string | null;
  waterTargetLiters?: number | string | null;
}

export interface MacroTargetResult {
  dailyCalories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
  waterTargetLiters: number;
  bmr: number;
  tdee: number;
  normalizedGoal: 'Fat Loss' | 'Lean Bulk' | 'Maintenance' | 'Athletic Performance' | 'Custom Goal';
  isMissingAssessmentData: boolean;
  missingDataNotes?: string;
  rationale: string;
  assumptions: string;
}

export function calculatePersonalizedDietMacros(
  biometrics: ClientBiometrics,
  goalString: string,
  overrides?: MacroOverrides
): MacroTargetResult {
  const rawWeight = Number(biometrics.weightKg);
  const rawHeight = Number(biometrics.heightCm);
  const rawAge = Number(biometrics.age);
  const gender = (biometrics.gender || 'male').toLowerCase();

  const isMissingAssessmentData = !rawWeight || rawWeight <= 0 || !rawHeight || rawHeight <= 0;

  // Safe defaults if assessment data is incomplete, while flagging for coach review
  const weightKg = !isMissingAssessmentData ? rawWeight : 70.0;
  const heightCm = !isMissingAssessmentData ? rawHeight : 175.0;
  const age = rawAge && rawAge > 0 && rawAge < 100 ? rawAge : 28;

  // 1. Basal Metabolic Rate (BMR) via Mifflin-St Jeor Equation
  const bmr = gender === 'female'
    ? Math.round(10 * weightKg + 6.25 * heightCm - 5 * age - 161)
    : Math.round(10 * weightKg + 6.25 * heightCm - 5 * age + 5);

  // 2. Activity Multiplier
  let activityMultiplier = 1.55; // MODERATE default (4-5 days)
  const trainingDays = Number(biometrics.trainingDaysPerWeek);
  const act = (biometrics.activityLevel || '').toUpperCase();

  if (trainingDays >= 6 || act.includes('HIGH') || act.includes('VERY_ACTIVE') || act.includes('ATHLETE')) {
    activityMultiplier = 1.725;
  } else if (trainingDays === 4 || trainingDays === 5 || act.includes('MODERATE')) {
    activityMultiplier = 1.55;
  } else if (trainingDays === 3 || act.includes('LIGHT')) {
    activityMultiplier = 1.375;
  } else if ((trainingDays > 0 && trainingDays <= 2) || act.includes('SEDENTARY') || act.includes('LOW')) {
    activityMultiplier = 1.2;
  }

  const tdee = Math.round(bmr * activityMultiplier);

  // 3. Goal Categorization
  const goalClean = (goalString || '').trim();
  let normalizedGoal: MacroTargetResult['normalizedGoal'] = 'Maintenance';

  if (/fat[ -]?loss|cutting|cut|weight[ -]?loss|lean[ -]?out|deficit/i.test(goalClean)) {
    normalizedGoal = 'Fat Loss';
  } else if (/lean[ -]?bulk|lean muscle|hypertrophy|muscle[ -]?gain|bulking|mass[ -]?gain|bulk/i.test(goalClean)) {
    normalizedGoal = 'Lean Bulk';
  } else if (/athletic|performance|endurance|sport|stamina/i.test(goalClean)) {
    normalizedGoal = 'Athletic Performance';
  } else if (/maintenance|maintain|recomp|recomposition|general/i.test(goalClean)) {
    normalizedGoal = 'Maintenance';
  } else if (goalClean.length > 0) {
    normalizedGoal = 'Custom Goal';
  }

  // 4. Calculate Goal-Specific Energy and Macronutrient Partitioning
  let targetCalories: number;
  let protein: number;
  let fat: number;
  let carbs: number;

  switch (normalizedGoal) {
    case 'Fat Loss': {
      // 20% deficit, minimum 1400 kcal
      targetCalories = Math.max(1400, Math.round(tdee * 0.80));
      // Muscle-preserving protein in a deficit: 2.2 g/kg bodyweight
      protein = Math.max(120, Math.round(weightKg * 2.2));
      // Essential fat: 22% of daily calories, floor of 0.7 g/kg or 40g
      const fatFromPct = Math.round((targetCalories * 0.22) / 9);
      const minFat = Math.max(40, Math.round(weightKg * 0.7));
      fat = Math.max(minFat, fatFromPct);
      // Remainder allocated to carbohydrates (minimum 50g)
      const remainingCals = targetCalories - (protein * 4 + fat * 9);
      carbs = Math.max(50, Math.round(remainingCals / 4));
      // Reconcile total calories exactly to 4P + 4C + 9F
      targetCalories = (protein * 4) + (carbs * 4) + (fat * 9);
      break;
    }

    case 'Lean Bulk': {
      // Controlled 10% surplus to support hypertrophy while minimizing fat accumulation
      targetCalories = Math.round(tdee * 1.10);
      // Optimal protein for hypertrophy: 2.0 g/kg bodyweight
      protein = Math.max(120, Math.round(weightKg * 2.0));
      // Healthy fats: 25% of daily calories, floor of 0.8 g/kg or 50g
      const fatFromPct = Math.round((targetCalories * 0.25) / 9);
      const minFat = Math.max(50, Math.round(weightKg * 0.8));
      fat = Math.max(minFat, fatFromPct);
      // Remainder allocated to carbohydrates to fuel heavy resistance training
      const remainingCals = targetCalories - (protein * 4 + fat * 9);
      carbs = Math.max(100, Math.round(remainingCals / 4));
      // Reconcile total calories exactly to 4P + 4C + 9F
      targetCalories = (protein * 4) + (carbs * 4) + (fat * 9);
      break;
    }

    case 'Athletic Performance': {
      // Elevated caloric baseline (1.08 TDEE) to meet athletic training volume demands
      targetCalories = Math.round(tdee * 1.08);
      // Protein for athletic recovery: 1.9 g/kg bodyweight
      protein = Math.max(120, Math.round(weightKg * 1.9));
      // Moderate fat (20% of calories) to prioritize carbohydrate availability for glycogen replenishment
      fat = Math.max(45, Math.round((targetCalories * 0.20) / 9));
      // High carbohydrate allocation to optimize athletic performance and endurance
      const remainingCals = targetCalories - (protein * 4 + fat * 9);
      carbs = Math.max(120, Math.round(remainingCals / 4));
      // Reconcile total calories exactly to 4P + 4C + 9F
      targetCalories = (protein * 4) + (carbs * 4) + (fat * 9);
      break;
    }

    case 'Maintenance':
    case 'Custom Goal':
    default: {
      // Energy balance: 1.00 TDEE
      targetCalories = Math.round(tdee);
      // Baseline protein: 1.8 g/kg bodyweight
      protein = Math.max(110, Math.round(weightKg * 1.8));
      // Balanced fat: 25% of calories
      fat = Math.max(45, Math.round((targetCalories * 0.25) / 9));
      // Remainder to carbohydrates
      const remainingCals = targetCalories - (protein * 4 + fat * 9);
      carbs = Math.max(80, Math.round(remainingCals / 4));
      // Reconcile total calories exactly to 4P + 4C + 9F
      targetCalories = (protein * 4) + (carbs * 4) + (fat * 9);
      break;
    }
  }

  // 5. Check if caller provided explicit, verified custom macro overrides (e.g. coach adjusted inputs)
  // Only override if the caller passed explicit non-default values and intended custom values
  const overrideCal = Number(overrides?.dailyCalories);
  const overridePro = Number(overrides?.protein);
  const overrideCarb = Number(overrides?.carbohydrates);
  const overrideFat = Number(overrides?.fat);

  if (overrideCal > 0 && overridePro > 0 && overrideCarb >= 0 && overrideFat >= 0) {
    // If all 4 are explicitly supplied, check if they differ from the generic stagnant 2000/160/200/55
    const isStagnantDefault = overrideCal === 2000 && overridePro === 160 && overrideCarb === 200 && overrideFat === 55;
    if (!isStagnantDefault || normalizedGoal === 'Custom Goal') {
      targetCalories = Math.round(overrideCal);
      protein = Math.round(overridePro);
      carbs = Math.round(overrideCarb);
      fat = Math.round(overrideFat);

      // Validate energy balance within reasonable tolerance: |targetCalories - (4P+4C+9F)|
      const macroCal = (protein * 4) + (carbs * 4) + (fat * 9);
      if (Math.abs(targetCalories - macroCal) > 10) {
        // Harmonize calories with macros to ensure exact math
        targetCalories = macroCal;
      }
    }
  }

  // 6. Fiber and Hydration Targets
  const fiberOverride = Number(overrides?.fiber);
  const fiber = fiberOverride && fiberOverride >= 15 && fiberOverride <= 60
    ? Math.round(fiberOverride)
    : Math.min(45, Math.max(25, Math.round(targetCalories * 0.014))); // ~14g per 1000 kcal

  const waterOverride = Number(overrides?.waterTargetLiters);
  const waterTargetLiters = waterOverride && waterOverride >= 1.5 && waterOverride <= 6.0
    ? Math.round(waterOverride * 10) / 10
    : Math.max(3.0, Math.round(weightKg * 0.04 * 10) / 10);

  // 7. Rationale and Assumptions
  let rationale = `Nutritional distribution formulated for athlete based on assessment metrics (${weightKg} kg, ${heightCm} cm), ${normalizedGoal} objective, and ${activityMultiplier} activity multiplier.`;
  let assumptions = `Mifflin-St Jeor BMR: ${bmr} kcal, TDEE: ${tdee} kcal. Macro targets: ${targetCalories} kcal, ${protein}g protein (${(protein / weightKg).toFixed(1)}g/kg), ${carbs}g carbs, ${fat}g fat, ${fiber}g fiber. Water target: ${waterTargetLiters}L/day.`;
  let missingDataNotes: string | undefined = undefined;

  if (isMissingAssessmentData) {
    missingDataNotes = 'Client assessment is missing bodyweight and/or height. Baseline reference metrics (70kg, 175cm) used. Update client assessment for precise prescription.';
    assumptions = `[ATTENTION: Incomplete Client Biometrics] Standard reference baseline (70kg, 175cm) used. ${assumptions}`;
    rationale = `Preliminary estimation using baseline reference data due to incomplete athlete biometrics. Flagged for coach review before approval.`;
  }

  return {
    dailyCalories: targetCalories,
    protein,
    carbohydrates: carbs,
    fat,
    fiber,
    waterTargetLiters,
    bmr,
    tdee,
    normalizedGoal,
    isMissingAssessmentData,
    missingDataNotes,
    rationale,
    assumptions,
  };
}

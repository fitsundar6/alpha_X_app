/**
 * Alpha X Gym — Scientific Diet & Macro Personalization Engine
 *
 * Implements Mifflin-St Jeor Energy Estimation, Activity Scaling,
 * and Goal-Based Macronutrient Distribution:
 * - Male BMR = (10 × weight in kg) + (6.25 × height in cm) − (5 × age) + 5
 * - Female BMR = (10 × weight in kg) + (6.25 × height in cm) − (5 × age) − 161
 * - Unisex / Neutral BMR = (10 × weight in kg) + (6.25 × height in cm) − (5 × age) − 78 (Midpoint estimation)
 * - TDEE = BMR × Activity Factor (Sedentary: 1.20, Light: 1.375, Moderate: 1.55, Very Active: 1.725, Extra Active: 1.90)
 * - Goal Adjustments:
 *   - Fat Loss: Moderate deficit (-15% to -20%, default -20%), muscle-preserving protein (2.2 g/kg), essential fat, remainder carbs.
 *   - Lean Bulk: Modest surplus (+5% to +10%, default +10%), hypertrophy protein (2.0 g/kg), moderate fat (25%), high carbs.
 *   - Maintenance: Caloric balance (1.00 TDEE), baseline protein (1.8 g/kg), balanced fat & carbs.
 *   - Athletic Performance: High performance demand (+8% or volume adjusted), 1.9 g/kg protein, glycogen-replenishing high carbs.
 *   - Custom Goal: Preserves coach custom values or custom goal instructions.
 *
 * Strict energy balance validation: 4*Protein + 4*Carbs + 9*Fat ≈ Calories.
 * Incomplete assessment metrics are flagged for admin review.
 */

export interface ClientBiometrics {
  weightKg?: number | string | null;
  heightCm?: number | string | null;
  age?: number | string | null;
  gender?: string | null; // 'male' | 'female' | 'other' | 'neutral' | 'unisex'
  sex?: string | null;
  activityLevel?: string | null;
  activityMultiplier?: number | string | null;
  trainingDaysPerWeek?: number | string | null;
  calorieAdjustmentPct?: number | string | null;
  proteinGramsPerKg?: number | string | null;
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
  bmrEquationUsed: 'male' | 'female' | 'unisex_midpoint';
  activityMultiplier: number;
  calorieAdjustmentPct: number;
  normalizedGoal: 'Fat Loss' | 'Lean Bulk' | 'Maintenance' | 'Athletic Performance' | 'Custom Goal';
  isMissingAssessmentData: boolean;
  missingDataNotes?: string;
  safetyWarning?: string;
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
  const sexClean = (biometrics.sex || biometrics.gender || 'male').toLowerCase().trim();

  const isMissingAssessmentData = !rawWeight || rawWeight <= 0 || !rawHeight || rawHeight <= 0;

  // Safe reference defaults if assessment data is incomplete, while flagging for coach review
  const weightKg = !isMissingAssessmentData ? rawWeight : 70.0;
  const heightCm = !isMissingAssessmentData ? rawHeight : 175.0;
  const age = rawAge && rawAge > 0 && rawAge < 100 ? rawAge : 28;

  // 1. Basal Metabolic Rate (BMR) via Mifflin-St Jeor Equation
  let bmrEquationUsed: MacroTargetResult['bmrEquationUsed'] = 'male';
  let bmr: number;

  if (sexClean === 'female' || sexClean === 'f') {
    bmrEquationUsed = 'female';
    bmr = Math.round(10 * weightKg + 6.25 * heightCm - 5 * age - 161);
  } else if (sexClean === 'male' || sexClean === 'm') {
    bmrEquationUsed = 'male';
    bmr = Math.round(10 * weightKg + 6.25 * heightCm - 5 * age + 5);
  } else {
    // Sex-neutral / Unisex midpoint equation
    bmrEquationUsed = 'unisex_midpoint';
    bmr = Math.round(10 * weightKg + 6.25 * heightCm - 5 * age - 78);
  }

  // 2. Activity Multiplier (Configurable / Standard)
  let activityMultiplier = 1.55; // MODERATE default
  const directMultiplier = Number(biometrics.activityMultiplier);

  if (directMultiplier >= 1.0 && directMultiplier <= 2.5) {
    activityMultiplier = directMultiplier;
  } else {
    const trainingDays = Number(biometrics.trainingDaysPerWeek);
    const act = (biometrics.activityLevel || '').toUpperCase();

    if (act.includes('EXTRA') || (trainingDays >= 7 && act.includes('HIGH'))) {
      activityMultiplier = 1.90;
    } else if (trainingDays >= 6 || act.includes('HIGH') || act.includes('VERY_ACTIVE') || act.includes('ATHLETE')) {
      activityMultiplier = 1.725;
    } else if (trainingDays === 4 || trainingDays === 5 || act.includes('MODERATE')) {
      activityMultiplier = 1.55;
    } else if (trainingDays === 3 || act.includes('LIGHT')) {
      activityMultiplier = 1.375;
    } else if ((trainingDays > 0 && trainingDays <= 2) || act.includes('SEDENTARY') || act.includes('LOW')) {
      activityMultiplier = 1.20;
    }
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

  // 4. Goal-Based Calorie Adjustment
  let defaultAdjustmentPct = 0;
  if (normalizedGoal === 'Fat Loss') defaultAdjustmentPct = -20;
  else if (normalizedGoal === 'Lean Bulk') defaultAdjustmentPct = 10;
  else if (normalizedGoal === 'Athletic Performance') defaultAdjustmentPct = 8;
  else defaultAdjustmentPct = 0;

  const rawAdjustmentPct = biometrics.calorieAdjustmentPct !== undefined && biometrics.calorieAdjustmentPct !== null && biometrics.calorieAdjustmentPct !== ''
    ? Number(biometrics.calorieAdjustmentPct)
    : defaultAdjustmentPct;

  const calorieAdjustmentPct = !isNaN(rawAdjustmentPct) ? rawAdjustmentPct : defaultAdjustmentPct;

  let targetCalories = Math.max(1200, Math.round(tdee * (1 + calorieAdjustmentPct / 100)));

  // 5. Automatic Macro Partitioning based on body weight
  let defaultProteinGPerKg = 1.8;
  if (normalizedGoal === 'Fat Loss') defaultProteinGPerKg = 2.2;
  else if (normalizedGoal === 'Lean Bulk') defaultProteinGPerKg = 2.0;
  else if (normalizedGoal === 'Athletic Performance') defaultProteinGPerKg = 1.9;
  else defaultProteinGPerKg = 1.8;

  const rawProteinRatio = Number(biometrics.proteinGramsPerKg);
  const proteinGramsPerKg = rawProteinRatio >= 1.2 && rawProteinRatio <= 3.5 ? rawProteinRatio : defaultProteinGPerKg;

  let protein = Math.max(90, Math.round(weightKg * proteinGramsPerKg));

  // Fat range: 20-25% of calories, floor of 0.7-0.8 g/kg
  let fatPct = 0.25;
  let minFatGPerKg = 0.8;
  if (normalizedGoal === 'Fat Loss') {
    fatPct = 0.22;
    minFatGPerKg = 0.7;
  } else if (normalizedGoal === 'Athletic Performance') {
    fatPct = 0.20;
    minFatGPerKg = 0.7;
  }

  const fatFromPct = Math.round((targetCalories * fatPct) / 9);
  const minFat = Math.max(40, Math.round(weightKg * minFatGPerKg));
  let fat = Math.max(minFat, fatFromPct);

  // Remainder to carbohydrates
  let remainingCals = targetCalories - (protein * 4 + fat * 9);
  let carbs = Math.max(30, Math.round(remainingCals / 4));

  // If protein + fat exceeded target calories, adjust fat slightly to avoid negative carbs
  if (remainingCals < 120) {
    fat = Math.max(minFat, Math.round((targetCalories * 0.20) / 9));
    remainingCals = targetCalories - (protein * 4 + fat * 9);
    carbs = Math.max(30, Math.round(remainingCals / 4));
  }

  // Reconcile total calories exactly to 4P + 4C + 9F
  targetCalories = (protein * 4) + (carbs * 4) + (fat * 9);

  // 6. Check if caller provided explicit, verified custom macro overrides (e.g. coach adjusted inputs)
  const overrideCal = Number(overrides?.dailyCalories);
  const overridePro = Number(overrides?.protein);
  const overrideCarb = Number(overrides?.carbohydrates);
  const overrideFat = Number(overrides?.fat);

  if (overrideCal > 0 && overridePro > 0 && overrideCarb >= 0 && overrideFat >= 0) {
    const isStagnantDefault = overrideCal === 2000 && overridePro === 160 && overrideCarb === 200 && overrideFat === 55;
    if (!isStagnantDefault || normalizedGoal === 'Custom Goal') {
      targetCalories = Math.round(overrideCal);
      protein = Math.round(overridePro);
      carbs = Math.round(overrideCarb);
      fat = Math.round(overrideFat);

      // Validate energy balance within reasonable tolerance: |targetCalories - (4P+4C+9F)|
      const macroCal = (protein * 4) + (carbs * 4) + (fat * 9);
      if (Math.abs(targetCalories - macroCal) > 10) {
        targetCalories = macroCal;
      }
    }
  }

  // 7. Fiber and Hydration Targets
  const fiberOverride = Number(overrides?.fiber);
  const fiber = fiberOverride && fiberOverride >= 15 && fiberOverride <= 60
    ? Math.round(fiberOverride)
    : Math.min(45, Math.max(25, Math.round(targetCalories * 0.014))); // ~14g per 1000 kcal

  const waterOverride = Number(overrides?.waterTargetLiters);
  const waterTargetLiters = waterOverride && waterOverride >= 1.5 && waterOverride <= 6.0
    ? Math.round(waterOverride * 10) / 10
    : Math.max(3.0, Math.round(weightKg * 0.04 * 10) / 10);

  // 8. Safety Warnings & Clinical Safeguards
  let safetyWarning: string | undefined = undefined;
  if (targetCalories < 1200) {
    safetyWarning = 'Caution: Prescribed calorie target is below clinical minimum threshold (1200 kcal/day). Review nutritional safety before assigning.';
  } else if (carbs < 40) {
    safetyWarning = 'Carbohydrate allocation is critically low. Verify that daily calorie target adequately covers minimum physiological needs.';
  } else if (calorieAdjustmentPct < -30) {
    safetyWarning = 'Aggressive caloric deficit (>30%). Monitor athlete energy levels and muscle retention closely.';
  }

  // 9. Rationale and Assumptions
  const sexEquationDesc = bmrEquationUsed === 'male'
    ? 'Mifflin-St Jeor (Male)'
    : (bmrEquationUsed === 'female' ? 'Mifflin-St Jeor (Female)' : 'Mifflin-St Jeor (Sex-Neutral Midpoint)');

  let rationale = `Nutritional distribution formulated for athlete based on assessment metrics (${weightKg} kg, ${heightCm} cm), ${normalizedGoal} objective (${calorieAdjustmentPct >= 0 ? `+${calorieAdjustmentPct}%` : `${calorieAdjustmentPct}%`}), and ${activityMultiplier} activity factor.`;
  let assumptions = `Estimated BMR: ${bmr} kcal/day (${sexEquationDesc}), TDEE: ${tdee} kcal/day. Macro targets: ${targetCalories} kcal, ${protein}g protein (${(protein / weightKg).toFixed(1)}g/kg), ${carbs}g carbs, ${fat}g fat, ${fiber}g fiber. Water target: ${waterTargetLiters}L/day.`;
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
    bmrEquationUsed,
    activityMultiplier,
    calorieAdjustmentPct,
    normalizedGoal,
    isMissingAssessmentData,
    missingDataNotes,
    safetyWarning,
    rationale,
    assumptions,
  };
}

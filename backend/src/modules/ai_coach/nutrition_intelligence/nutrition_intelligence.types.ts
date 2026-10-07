/**
 * Alpha X AI — Nutrition Intelligence Engine Types
 * Phase 10 — Nutrition Intelligence Engine
 */

export type NutritionIntelligenceStatus =
  | 'SUCCESS'
  | 'NO_RECORDS_FOUND'
  | 'INSUFFICIENT_DATA'
  | 'INVALID_INPUT'
  | 'CLIENT_NOT_FOUND'
  | 'AMBIGUOUS_CLIENT';

export interface NutritionIntelligenceResult<T = any> {
  status: NutritionIntelligenceStatus;
  clientId: string;
  metric: string;
  value: T;
  unit: string;
  dateRange?: {
    startDate: string | null;
    endDate: string | null;
  };
  recordCount: number;
  source: 'ALPHA_X_DATABASE';
  calculationMethod: 'DETERMINISTIC_CALCULATION';
  dataQuality?: string;
  message?: string;
}

export interface RawFoodLogItem {
  id: string;
  dateString: string; // 'YYYY-MM-DD'
  mealType: string;   // 'Breakfast', 'Lunch', 'Snacks', 'Dinner', etc.
  foodName: string;
  category: string;
  servingSize: number;
  servingUnit: string;
  quantity: number;
  calories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
  source?: string;
  weightSource?: string;
  mealId?: string | null;
  loggedAt?: Date | string;
}

export interface NutritionTarget {
  planName: string;
  dailyCalories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
  waterTargetLiters?: number;
  source: 'DIET_PLAN' | 'MACRO_PLAN';
}

export interface MacroCaloriesAndPercentages {
  proteinKcal: number;
  carbsKcal: number;
  fatKcal: number;
  totalMacroKcal: number;
  proteinPct: number;
  carbsPct: number;
  fatPct: number;
}

export interface FoodItemSummary {
  foodName: string;
  category: string;
  quantity: number;
  servingSize: number;
  servingUnit: string;
  calories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
}

export interface MealSummary {
  mealType: string;
  itemsCount: number;
  calories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
  percentageOfDailyCalories: number;
  items: FoodItemSummary[];
}

export interface DailyNutritionBreakdown {
  date: string; // YYYY-MM-DD
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
  totalFiber: number;
  macroCalories: {
    proteinKcal: number;
    carbsKcal: number;
    fatKcal: number;
  };
  macroPercentages: {
    proteinPct: number;
    carbsPct: number;
    fatPct: number;
  };
  loggedItemsCount: number;
  mealCounts: { [mealType: string]: number };
  meals: { [mealType: string]: MealSummary };
  targetComparison?: {
    targetCalories: number;
    targetProtein: number;
    targetCarbs: number;
    targetFat: number;
    targetFiber: number;
    calorieDiff: number;
    proteinDiff: number;
    carbsDiff: number;
    fatDiff: number;
    fiberDiff: number;
    calorieAdherencePct: number;
    proteinAdherencePct: number;
    isCalorieCompliant: boolean; // within ±10%
    isProteinCompliant: boolean; // >= 90%
  };
}

export interface NutritionSummaryAnalysis {
  dateRange: {
    startDate: string | null;
    endDate: string | null;
    elapsedDays: number;
  };
  totalLoggedCalories: number;
  totalLoggedProtein: number;
  totalLoggedCarbs: number;
  totalLoggedFat: number;
  totalLoggedFiber: number;
  distinctLoggedDays: number;
  unloggedDaysCount: number;
  loggingAdherencePct: number; // (distinctLoggedDays / elapsedDays) * 100
  totalLogsCount: number;
  averageDailyCalories: number; // over distinct logged days
  averageDailyProtein: number;
  averageDailyCarbs: number;
  averageDailyFat: number;
  averageDailyFiber: number;
  calendarAverageDailyCalories: number; // over elapsed calendar days
  macroCaloricSplit: MacroCaloriesAndPercentages;
  targetComparison?: {
    hasActiveTarget: boolean;
    target: NutritionTarget | null;
    difference: {
      calories: number;
      protein: number;
      carbs: number;
      fat: number;
      fiber: number;
    };
    adherencePercentage: {
      calories: number;
      protein: number;
      carbs: number;
      fat: number;
    };
    complianceDays: {
      calorieCompliantDays: number;
      proteinCompliantDays: number;
      totalLoggedDays: number;
      calorieComplianceRate: number; // % of logged days within ±10%
      proteinComplianceRate: number; // % of logged days >= 90%
    };
  };
  missingData: {
    unrecordedDays: string[];
    zeroValueLogsCount: number;
    missingFiberLogsCount: number;
    dataCompletenessScore: number; // 0-100%
  };
}

export interface WeeklyNutritionRollup {
  weekLabel: string;
  startDate: string;
  endDate: string;
  loggedDaysCount: number;
  averageDailyCalories: number;
  averageDailyProtein: number;
  averageDailyCarbs: number;
  averageDailyFat: number;
  averageDailyFiber: number;
}

export interface NutritionHistoryAnalysis {
  dateRange: {
    startDate: string | null;
    endDate: string | null;
    elapsedDays: number;
  };
  distinctLoggedDays: number;
  dailyBreakdowns: DailyNutritionBreakdown[];
  weeklyRollups: WeeklyNutritionRollup[];
  trends: {
    calorieTrend: 'INCREASING' | 'DECREASING' | 'STABLE' | 'INSUFFICIENT_DATA';
    proteinTrend: 'INCREASING' | 'DECREASING' | 'STABLE' | 'INSUFFICIENT_DATA';
    calorieChangeAvg: number;
    proteinChangeAvg: number;
  };
  extremes: {
    highestCalorieDay: { date: string; calories: number } | null;
    lowestCalorieDay: { date: string; calories: number } | null;
    highestProteinDay: { date: string; protein: number } | null;
    lowestProteinDay: { date: string; protein: number } | null;
  };
}

export interface MealBreakdownTypeStats {
  mealType: string;
  totalLogsCount: number;
  daysLoggedCount: number;
  totalCalories: number;
  averageCalories: number;
  totalProtein: number;
  averageProtein: number;
  totalCarbs: number;
  averageCarbs: number;
  totalFat: number;
  averageFat: number;
  totalFiber: number;
  averageFiber: number;
  percentageOfTotalCalories: number;
  topFoods: Array<{
    foodName: string;
    occurrences: number;
    totalCalories: number;
  }>;
}

export interface MealBreakdownAnalysis {
  dateRange: {
    startDate: string | null;
    endDate: string | null;
  };
  totalLoggedMeals: number;
  distinctLoggedDays: number;
  mealTypeBreakdown: MealBreakdownTypeStats[];
  mostFrequentMealType: string | null;
  highestCalorieMealType: string | null;
  highestProteinMealType: string | null;
}

export interface NutritionPeriodComparison {
  period1: {
    label: string;
    dateRange: { startDate: string; endDate: string };
    summary: NutritionSummaryAnalysis;
  };
  period2: {
    label: string;
    dateRange: { startDate: string; endDate: string };
    summary: NutritionSummaryAnalysis;
  };
  deltas: {
    caloriesDelta: number; // P2 - P1
    caloriesPercentageChange: number | null;
    proteinDelta: number;
    proteinPercentageChange: number | null;
    carbsDelta: number;
    carbsPercentageChange: number | null;
    fatDelta: number;
    fatPercentageChange: number | null;
    fiberDelta: number;
    fiberPercentageChange: number | null;
    loggedDaysDelta: number;
    loggingAdherenceDeltaPct: number;
    calorieAdherenceDeltaPct?: number | null;
    proteinAdherenceDeltaPct?: number | null;
  };
  direction: {
    calories: 'INCREASED' | 'DECREASED' | 'UNCHANGED';
    protein: 'INCREASED' | 'DECREASED' | 'UNCHANGED';
    carbs: 'INCREASED' | 'DECREASED' | 'UNCHANGED';
    fat: 'INCREASED' | 'DECREASED' | 'UNCHANGED';
    adherence: 'IMPROVED' | 'DECLINED' | 'UNCHANGED';
  };
}

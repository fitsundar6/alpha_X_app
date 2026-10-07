/**
 * Alpha X AI — Nutrition Intelligence Errors
 * Phase 10 — Nutrition Intelligence Engine
 */

export class NutritionIntelligenceError extends Error {
  public readonly code: string;
  public readonly statusCode: number;

  constructor(message: string, code: string = 'NUTRITION_INTELLIGENCE_ERROR', statusCode: number = 400) {
    super(message);
    this.name = 'NutritionIntelligenceError';
    this.code = code;
    this.statusCode = statusCode;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class InsufficientNutritionDataError extends NutritionIntelligenceError {
  constructor(message: string = 'Insufficient nutrition data to perform requested analysis.') {
    super(message, 'INSUFFICIENT_NUTRITION_DATA', 422);
    this.name = 'InsufficientNutritionDataError';
  }
}

export class NutritionDateRangeError extends NutritionIntelligenceError {
  constructor(message: string = 'Invalid date range specified for nutrition analysis.') {
    super(message, 'INVALID_DATE_RANGE', 400);
    this.name = 'NutritionDateRangeError';
  }
}

export class InvalidNutritionInputError extends NutritionIntelligenceError {
  constructor(message: string = 'Invalid input parameters for nutrition calculation.') {
    super(message, 'INVALID_INPUT', 400);
    this.name = 'InvalidNutritionInputError';
  }
}

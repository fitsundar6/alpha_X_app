/**
 * Alpha X AI — Calculation Engine Error Classes
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

export class CalculationError extends Error {
  public readonly code: string;
  public readonly metric: string;

  constructor(metric: string, message: string, code: string = 'CALCULATION_ERROR') {
    super(`[Calculation Error: ${metric}] ${message}`);
    this.name = 'CalculationError';
    this.code = code;
    this.metric = metric;
  }
}

export class InsufficientDataError extends CalculationError {
  constructor(metric: string, message: string) {
    super(metric, message, 'INSUFFICIENT_DATA');
    this.name = 'InsufficientDataError';
  }
}

export class InvalidCalculationInputError extends CalculationError {
  constructor(metric: string, message: string) {
    super(metric, message, 'INVALID_INPUT');
    this.name = 'InvalidCalculationInputError';
  }
}

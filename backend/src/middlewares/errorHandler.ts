import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { HttpStatus } from '../constants/httpStatus';
import { sendError } from '../utils/responseEnvelope';
import { env } from '../config/environment';

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly errorCode: string;
  public readonly details?: Array<{ field?: string; message: string }>;

  constructor(
    message: string,
    statusCode: number = HttpStatus.BAD_REQUEST,
    errorCode: string = 'BAD_REQUEST',
    details?: Array<{ field?: string; message: string }>
  ) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (
  err: Error | AppError,
  _req: Request,
  res: Response,
  _next: NextFunction
): void => {
  // Handle Zod validation errors
  if (err instanceof ZodError) {
    const details = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
    }));
    sendError(res, 'VALIDATION_ERROR', 'Input validation failed', HttpStatus.UNPROCESSABLE_ENTITY, details);
    return;
  }

  // Handle custom AppError
  if (err instanceof AppError) {
    sendError(res, err.errorCode, err.message, err.statusCode, err.details);
    return;
  }

  // Catch unhandled internal errors safely
  if (env.NODE_ENV !== 'production') {
    console.error('Unhandled Server Error:', err);
  }

  sendError(
    res,
    'INTERNAL_SERVER_ERROR',
    env.NODE_ENV === 'production' ? 'An unexpected server error occurred' : err.message,
    HttpStatus.INTERNAL_SERVER_ERROR
  );
};

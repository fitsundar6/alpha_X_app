import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { HttpStatus } from '../constants/httpStatus';
import { sendError } from '../utils/responseEnvelope';
import { extractDatabaseError } from '../utils/serverLogger';

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
  err: any,
  _req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (res.headersSent) {
    return next(err);
  }

  // Handle JSON parse syntax errors from express.json()
  if (err?.name === 'SyntaxError' && 'body' in err) {
    sendError(
      res,
      'INVALID_JSON',
      `Malformed JSON syntax in request body: ${err.message}`,
      HttpStatus.BAD_REQUEST,
      undefined,
      err
    );
    return;
  }

  // Handle Zod validation errors
  if (err instanceof ZodError) {
    const details = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
    }));
    sendError(
      res,
      'VALIDATION_ERROR',
      'Input validation failed',
      HttpStatus.UNPROCESSABLE_ENTITY,
      details,
      err
    );
    return;
  }

  // Handle custom AppError
  if (err instanceof AppError) {
    sendError(res, err.errorCode, err.message, err.statusCode, err.details, err);
    return;
  }

  // Handle Database / Prisma errors
  const dbError = extractDatabaseError(err);
  if (dbError) {
    sendError(
      res,
      'DATABASE_ERROR',
      err.message || 'Database query or connection failed',
      HttpStatus.INTERNAL_SERVER_ERROR,
      undefined,
      err
    );
    return;
  }

  // Handle any other unexpected server error with full error & stack trace
  sendError(
    res,
    'INTERNAL_SERVER_ERROR',
    err?.message || 'An unexpected server error occurred',
    HttpStatus.INTERNAL_SERVER_ERROR,
    undefined,
    err
  );
};

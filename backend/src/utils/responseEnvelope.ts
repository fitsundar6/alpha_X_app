import { Request, Response } from 'express';
import { HttpStatus } from '../constants/httpStatus';
import {
  logActivity,
  logServerError,
  extractRequestId,
  extractClientId,
  extractDatabaseError,
} from './serverLogger';

export interface ApiResponseMeta {
  timestamp: string;
  version: string;
  requestId?: string;
}

export interface ApiSuccessResponse<T> {
  success: true;
  data: T;
  error: null;
  meta: ApiResponseMeta;
}

export interface ApiErrorDetail {
  field?: string;
  message: string;
}

export interface ApiErrorResponse {
  success: false;
  data: null;
  error: {
    code: string;
    message: string;
    details?: ApiErrorDetail[];
  };
  meta: ApiResponseMeta;
}

export interface ErrorContext {
  activity?: string;
  resourceId?: string;
  resourceType?: string;
  explanation?: string;
  receivedPayload?: any;
}

const getMeta = (requestId?: string): ApiResponseMeta => ({
  timestamp: new Date().toISOString(),
  version: '1.0.0',
  ...(requestId ? { requestId } : {}),
});

/**
 * Standardized success response sender
 * Automatically logs clear [ACTION SUCCESS] with action details, latency, and IDs.
 */
export const sendSuccess = <T>(
  res: Response,
  data: T,
  statusCode: number = HttpStatus.OK,
  activity?: string,
  details?: any
): Response => {
  const req = (res as any).req as Request | undefined;
  const requestId = req?.id || (req ? extractRequestId(req, res) : undefined);
  const clientId = req ? extractClientId(req) : undefined;

  // Mark as logged so fallback middleware avoids duplicate entry
  (res as any).locals = (res as any).locals || {};
  (res as any).locals.__logged = true;

  // Compute default activity description if not provided
  let actDesc = activity;
  if (!actDesc && req) {
    const method = req.method;
    const url = req.originalUrl || req.url;
    actDesc = `${method} ${url} completed successfully`;
  }

  logActivity({
    req,
    method: req?.method,
    url: req?.originalUrl || req?.url,
    statusCode,
    activity: actDesc,
    reason: actDesc || 'Operation completed successfully',
    requestId,
    clientId,
    details,
  });

  const response: ApiSuccessResponse<T> = {
    success: true,
    data,
    error: null,
    meta: getMeta(requestId),
  };
  return res.status(statusCode).json(response);
};

/**
 * Standardized error response sender
 * Automatically logs clear [ACTION BAD REQUEST], [ACTION NOT FOUND], [ACTION AUTH FAILURE],
 * or [ACTION SYSTEM FAILURE] with the actual accurate reason, queried resource ID, and failing fields.
 */
export const sendError = (
  res: Response,
  code: string,
  message: string,
  statusCode: number = HttpStatus.BAD_REQUEST,
  details?: ApiErrorDetail[],
  rawError?: any,
  context?: ErrorContext
): Response => {
  const req = (res as any).req as Request | undefined;
  const requestId = req ? extractRequestId(req, res) : undefined;
  const clientId = req ? extractClientId(req) : undefined;
  const databaseError = rawError ? extractDatabaseError(rawError) : undefined;

  let stack = rawError instanceof Error ? rawError.stack : undefined;
  if (!stack && statusCode >= 500) {
    stack = new Error(message).stack;
  }

  // Mark error as logged so downstream response finish hook avoids duplicate logging
  (res as any).locals = (res as any).locals || {};
  (res as any).locals.__logged = true;

  // Determine queried resource ID if not explicitly given
  let resourceId = context?.resourceId;
  let resourceType = context?.resourceType;
  if (!resourceId && req?.params?.id) {
    resourceId = String(req.params.id);
  }
  if (!resourceType && req?.originalUrl) {
    if (req.originalUrl.includes('workout')) resourceType = 'WorkoutSession';
    else if (req.originalUrl.includes('exercise')) resourceType = 'Exercise';
    else if (req.originalUrl.includes('client')) resourceType = 'ClientProfile';
    else if (req.originalUrl.includes('food')) resourceType = 'FoodItem';
  }

  logServerError({
    req,
    method: req?.method,
    url: req?.originalUrl || req?.url,
    statusCode,
    errorCode: code,
    errorMessage: message,
    activity: context?.activity,
    explanation: context?.explanation,
    resourceId,
    resourceType,
    receivedPayload: context?.receivedPayload || req?.body,
    requestId,
    clientId,
    databaseError,
    details,
    stack,
    error: rawError,
  });

  const response: ApiErrorResponse = {
    success: false,
    data: null,
    error: {
      code,
      message,
      ...(details ? { details } : {}),
    },
    meta: getMeta(requestId),
  };
  return res.status(statusCode).json(response);
};

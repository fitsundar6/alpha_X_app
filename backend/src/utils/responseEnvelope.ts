import { Request, Response } from 'express';
import { HttpStatus } from '../constants/httpStatus';
import {
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

const getMeta = (requestId?: string): ApiResponseMeta => ({
  timestamp: new Date().toISOString(),
  version: '1.0.0',
  ...(requestId ? { requestId } : {}),
});

export const sendSuccess = <T>(
  res: Response,
  data: T,
  statusCode: number = HttpStatus.OK
): Response => {
  const req = (res as any).req as Request | undefined;
  const requestId = req?.id || (req ? extractRequestId(req, res) : undefined);
  const response: ApiSuccessResponse<T> = {
    success: true,
    data,
    error: null,
    meta: getMeta(requestId),
  };
  return res.status(statusCode).json(response);
};

export const sendError = (
  res: Response,
  code: string,
  message: string,
  statusCode: number = HttpStatus.BAD_REQUEST,
  details?: ApiErrorDetail[],
  rawError?: any
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
  (res as any).locals.__errorLogged = true;

  logServerError({
    req,
    method: req?.method,
    url: req?.originalUrl || req?.url,
    statusCode,
    errorCode: code,
    errorMessage: message,
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


import { Response } from 'express';
import { HttpStatus } from '../constants/httpStatus';

export interface ApiResponseMeta {
  timestamp: string;
  version: string;
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

const getMeta = (): ApiResponseMeta => ({
  timestamp: new Date().toISOString(),
  version: '1.0.0',
});

export const sendSuccess = <T>(
  res: Response,
  data: T,
  statusCode: number = HttpStatus.OK
): Response => {
  const response: ApiSuccessResponse<T> = {
    success: true,
    data,
    error: null,
    meta: getMeta(),
  };
  return res.status(statusCode).json(response);
};

export const sendError = (
  res: Response,
  code: string,
  message: string,
  statusCode: number = HttpStatus.BAD_REQUEST,
  details?: ApiErrorDetail[]
): Response => {
  const response: ApiErrorResponse = {
    success: false,
    data: null,
    error: {
      code,
      message,
      ...(details ? { details } : {}),
    },
    meta: getMeta(),
  };
  return res.status(statusCode).json(response);
};

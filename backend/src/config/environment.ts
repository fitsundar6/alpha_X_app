import path from 'path';
import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables from backend .env file or current working directory
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config();

const envSchema = z.object({
  PORT: z.string().default('5000').transform((val) => parseInt(val, 10)),
  HOST: z.string().default('0.0.0.0'),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET must be at least 16 characters'),
  JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET must be at least 16 characters'),
  JWT_ACCESS_EXPIRES_IN: z.string().default('30d'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('30d'),
  QR_SECRET_KEY: z.string().default('alpha_x_qr_dynamic_secret_key_rotation'),
  CORS_ORIGIN: z.string().default('*'),
  WGER_API_URL: z.string().default('https://wger.de/api/v2'),
  EXERCISE_DB_API_KEY: z.string().optional(),
  GEMINI_API_KEY: z.string().optional(),
  ONESIGNAL_APP_ID: z.string().optional(),
  ONESIGNAL_REST_API_KEY: z.string().optional(),
  PYTHON_AI_URL: z.string().default('http://127.0.0.1:8000/api/v1/ai'),
  // Master Administrator Email & Password Credentials
  // Exactly ONE authorized master admin account
  ADMIN_EMAIL: z.string().email().default('admin@alphaxgym.com'),
  ADMIN_PASSWORD: z.string().min(8, 'ADMIN_PASSWORD must be at least 8 characters if provided').optional(),
  ADMIN_PASSWORD_HASH: z.string().optional(),
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error('❌ Invalid environment variables configuration:');
  console.error(JSON.stringify(parsedEnv.error.format(), null, 2));
  process.exit(1);
}

export const env = parsedEnv.data;

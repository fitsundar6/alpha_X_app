import path from 'path';
import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables from backend .env file or current working directory
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config();

const envSchema = z
  .object({
    PORT: z.string().default('5000').transform((val) => parseInt(val, 10)),
    HOST: z.string().default('0.0.0.0'),
    NODE_ENV: z.enum(['development', 'test', 'production']).default(
      process.env.VERCEL_ENV === 'production' ? 'production' : 'development'
    ),
    VERCEL_ENV: z.enum(['production', 'preview', 'development']).optional(),
    DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
    JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET must be at least 16 characters'),
    JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET must be at least 16 characters'),
    JWT_ACCESS_EXPIRES_IN: z.string().default('30d'),
    JWT_REFRESH_EXPIRES_IN: z.string().default('30d'),
    CORS_ORIGIN: z.string().default('https://alpha-x-app.vercel.app,https://alphaxgym.com'),
    WGER_API_URL: z.string().default('https://wger.de/api/v2'),
    EXERCISE_DB_API_KEY: z.string().optional(),
    GEMINI_API_KEY: z.string().optional(),
    GEMINI_API_KEY_BACKUP: z.string().optional(),
    GEMINI_MODEL: z.string().default('gemini-flash-lite-latest'),
    ONESIGNAL_APP_ID: z.string().optional(),
    ONESIGNAL_REST_API_KEY: z.string().optional(),
    PYTHON_AI_URL: z.string().default('http://127.0.0.1:8000/api/v1/ai'),
    CRON_SECRET: z.string().optional(),
    // Public Support & Contact Email (for athlete support, distinct from privileged master admin)
    SUPPORT_EMAIL: z.string().email().default('support@alphaxgym.com'),
    // Master Administrator Email & Password Credentials
    // Exactly ONE authorized master admin account
    ADMIN_EMAIL: z.string().email().default('admin@alphaxgym.com'),
    ADMIN_ID: z.string().optional(),
    ADMIN_PASSWORD: z.string().min(8, 'ADMIN_PASSWORD must be at least 8 characters if provided').optional(),
    ADMIN_PASSWORD_HASH: z.string().optional(),
    // Email & SMTP Configuration for Password Recovery
    SMTP_HOST: z.string().optional(),
    SMTP_PORT: z.string().default('587').transform((val) => parseInt(val, 10)),
    SMTP_SECURE: z.string().default('false').transform((val) => val === 'true'),
    SMTP_USER: z.string().optional(),
    SMTP_PASS: z.string().optional(),
    SMTP_FROM: z.string().default('Alpha X Gym <noreply@alphaxgym.com>'),
    APP_URL: z.string().default('http://localhost:3000'),
  })
  .superRefine((data, ctx) => {
    const isProd =
      data.NODE_ENV === 'production' ||
      data.VERCEL_ENV === 'production' ||
      process.env.NODE_ENV === 'production' ||
      process.env.VERCEL_ENV === 'production';

    if (isProd) {
      // 1. Production must have explicitly configured non-placeholder ADMIN_PASSWORD or ADMIN_PASSWORD_HASH
      const hasAdminPassword =
        typeof data.ADMIN_PASSWORD === 'string' &&
        data.ADMIN_PASSWORD.trim().length >= 8;
      const hasAdminPasswordHash =
        typeof data.ADMIN_PASSWORD_HASH === 'string' &&
        data.ADMIN_PASSWORD_HASH.trim().length >= 50;

      const placeholderPasswords = [
        'alphaxadmin2026(!)',
        'adminpassword',
        'changeme',
        'password',
        'defaultpassword',
        'admin123',
        '12345678',
      ];
      const isPlaceholderPassword =
        data.ADMIN_PASSWORD &&
        placeholderPasswords.includes(data.ADMIN_PASSWORD.trim().toLowerCase());

      if (!hasAdminPassword && !hasAdminPasswordHash) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['ADMIN_PASSWORD'],
          message:
            'In production, either ADMIN_PASSWORD (min 8 chars) or ADMIN_PASSWORD_HASH must be explicitly configured.',
        });
      } else if (isPlaceholderPassword) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['ADMIN_PASSWORD'],
          message:
            'ADMIN_PASSWORD must not be a known static placeholder in production.',
        });
      }

      // 2. Production must have explicitly configured non-placeholder CRON_SECRET
      const hasCronSecret =
        typeof data.CRON_SECRET === 'string' &&
        data.CRON_SECRET.trim().length >= 16;

      const placeholderCronSecrets = [
        'cron_secret',
        'alpha_x_cron_secret',
        'changeme',
        'default',
        'secret',
        'password',
      ];
      const isPlaceholderCron =
        data.CRON_SECRET &&
        placeholderCronSecrets.includes(data.CRON_SECRET.trim().toLowerCase());

      if (!hasCronSecret) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['CRON_SECRET'],
          message:
            'In production, CRON_SECRET must be explicitly configured with at least 16 characters.',
        });
      } else if (isPlaceholderCron) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['CRON_SECRET'],
          message:
            'CRON_SECRET must not be a known static placeholder in production.',
        });
      }
    }
  });

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error('❌ Invalid environment variables configuration:');
  console.error(JSON.stringify(parsedEnv.error.format(), null, 2));
  process.exit(1);
}

export const env = parsedEnv.data;

export const isProduction = (): boolean =>
  env.NODE_ENV === 'production' || process.env.VERCEL_ENV === 'production';

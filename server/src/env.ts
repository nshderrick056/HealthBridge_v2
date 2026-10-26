import { z } from 'zod';

export const env = z
  .object({
    JWT_SECRET: z.string().min(32),
    JWT_REFRESH_SECRET: z.string().min(32),
    PORT: z.coerce.number().default(3000),
    // 32 bytes as hex; wraps each device's SMS key at rest.
    SMS_KEY_ENC_KEY: z.string().regex(/^[0-9a-f]{64}$/i),
    // The gateway callback URLs carry it as ?secret=... (Africa's Talking cannot set headers).
    SMS_WEBHOOK_SECRET: z.string().min(16),
    // Without these the server still stores alerts but cannot send the acknowledgement SMS.
    AT_USERNAME: z.string().optional(),
    AT_API_KEY: z.string().optional(),
    AT_SENDER: z.string().optional(),
    // Comma-separated browser origins allowed to call the API. Unset: any http://localhost or 127.0.0.1 port.
    CORS_ORIGINS: z.string().optional(),
  })
  .parse(process.env);

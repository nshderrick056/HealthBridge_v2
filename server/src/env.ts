import { z } from 'zod';

export const env = z
  .object({
    JWT_SECRET: z.string().min(32),
    JWT_REFRESH_SECRET: z.string().min(32),
    PORT: z.coerce.number().default(3000),
  })
  .parse(process.env);

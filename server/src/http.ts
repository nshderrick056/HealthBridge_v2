import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    res.status(400).json({ error: 'invalid_request', issues: err.issues });
  } else if (err instanceof HttpError) {
    res.status(err.status).json({ error: err.message });
  } else if (err?.type === 'entity.parse.failed') {
    res.status(400).json({ error: 'invalid_json' });
  } else {
    console.error(err);
    res.status(500).json({ error: 'internal_error' });
  }
};

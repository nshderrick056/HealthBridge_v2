import express from 'express';
import { authRouter } from './auth/routes';
import type { Db } from './db';
import { errorHandler } from './http';

export function createApp({ db }: { db: Db }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));

  // Reachability check for the app (HEAD is served by this GET). Never touches the DB.
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });
  app.use('/auth', authRouter(db));

  app.use(errorHandler);
  return app;
}

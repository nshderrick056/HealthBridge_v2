import express from 'express';
import { authRouter } from './auth/routes';
import type { Db } from './db';
import { devicesRouter } from './devices/routes';
import { errorHandler } from './http';
import type { SmsSender } from './sms/gateway';
import { smsRouter } from './sms/webhook';

export function createApp({ db, sender }: { db: Db; sender: SmsSender }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));

  // Reachability check for the app (HEAD is served by this GET). Never touches the DB.
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });
  app.use('/auth', authRouter(db));
  app.use('/devices', devicesRouter(db));
  app.use('/webhooks/sms', smsRouter(db, sender));

  app.use(errorHandler);
  return app;
}

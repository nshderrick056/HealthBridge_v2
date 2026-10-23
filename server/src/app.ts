import express from 'express';
import { chwAlertsRouter } from './alerts/routes';
import { authRouter } from './auth/routes';
import type { Db } from './db';
import { devicesRouter } from './devices/routes';
import { env } from './env';
import { errorHandler } from './http';
import type { SmsSender } from './sms/gateway';
import { smsRouter } from './sms/webhook';
import { syncRouter } from './sync/routes';

export function createApp({ db, sender }: { db: Db; sender: SmsSender }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));

  // The web build of the app calls the API cross-origin. Tokens travel in headers, never cookies.
  const allowed = env.CORS_ORIGINS ? env.CORS_ORIGINS.split(',').map((o) => o.trim()) : undefined;
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && (allowed ? allowed.includes(origin) : /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin))) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Headers', 'authorization, content-type');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
    }
    res.setHeader('Vary', 'Origin');
    if (req.method === 'OPTIONS') return void res.sendStatus(204);
    next();
  });

  // Reachability check for the app (HEAD is served by this GET). Never touches the DB.
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });
  app.use('/auth', authRouter(db));
  app.use('/devices', devicesRouter(db));
  app.use('/webhooks/sms', smsRouter(db, sender));
  app.use('/sync', syncRouter(db));
  app.use('/alerts', chwAlertsRouter(db));

  app.use(errorHandler);
  return app;
}

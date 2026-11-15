import express from 'express';
import { adminRouter } from './admin/routes';
import { authRouter } from './auth/routes';
import { devicesRouter } from './devices/routes';
import { env } from './env';
import type { Fb } from './firebase';
import { errorHandler } from './http';
import type { SmsSender } from './sms/gateway';
import { smsRouter } from './sms/webhook';
import { supervisorRouter } from './supervisor/routes';
import { visitsRouter } from './visits/merge';

// Patients, visits and internet alerts go from the app straight to Firestore under the security rules.
// This server does what an app must not: PIN sign-in, admin accounts and resets, device keys, the SMS
// gateway, alert status changes, and merging an SMS case with the full visit.
export function createApp({ fb, sender }: { fb: Fb; sender: SmsSender }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));

  // The web dashboard calls the API cross-origin. Tokens travel in headers, never cookies.
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

  // Reachability check for the app (HEAD is served by this GET). Never touches Firestore.
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });
  app.use('/auth', authRouter(fb));
  app.use('/devices', devicesRouter(fb));
  app.use('/admin', adminRouter(fb, sender));
  app.use('/visits', visitsRouter(fb));
  app.use('/webhooks/sms', smsRouter(fb, sender));
  app.use(supervisorRouter(fb, sender)); // GET /alerts, GET|PATCH /alerts/:id, GET /chws; guarded per route

  app.use(errorHandler);
  return app;
}

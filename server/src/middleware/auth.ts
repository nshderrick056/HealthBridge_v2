import type { RequestHandler } from 'express';
import { verifyAccess, type AccessClaims, type Role } from '../auth/tokens';

// The verified claims go in res.locals.auth for the route handlers.
export const requireAuth: RequestHandler = (req, res, next) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'unauthorized' });
    return;
  }
  try {
    res.locals.auth = verifyAccess(header.slice('Bearer '.length));
    next();
  } catch {
    res.status(401).json({ error: 'unauthorized' });
  }
};

export const requireRole =
  (...roles: Role[]): RequestHandler =>
  (_req, res, next) => {
    const auth = res.locals.auth as AccessClaims | undefined;
    if (auth && roles.includes(auth.role)) next();
    else res.status(403).json({ error: 'forbidden' });
  };

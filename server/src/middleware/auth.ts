import type { NextFunction, Request, Response } from 'express';
import type { Fb } from '../firebase';
import { HttpError } from '../http';

export type Role = 'chw' | 'supervisor' | 'admin';

/** Who is calling, from the Firebase ID token's custom claims (set by the server when the account was made). */
export type Caller = { uid: string; role: Role | undefined; hc: string | null };

/** Checks the Firebase ID token in `Authorization: Bearer ...`; a revoked or disabled account is refused. */
export const requireUser =
  (fb: Fb) => async (req: Request, res: Response, next: NextFunction) => {
    const m = /^Bearer (.+)$/.exec(req.get('authorization') ?? '');
    if (!m) return next(new HttpError(401, 'unauthorized'));
    try {
      const t = await fb.auth.verifyIdToken(m[1], true);
      res.locals.caller = { uid: t.uid, role: t.role as Role | undefined, hc: (t.hc as string) ?? null } satisfies Caller;
      next();
    } catch {
      next(new HttpError(401, 'unauthorized'));
    }
  };

export const requireRole =
  (...roles: Role[]) => (_req: Request, res: Response, next: NextFunction) => {
    const role = (res.locals.caller as Caller | undefined)?.role;
    next(role && roles.includes(role) ? undefined : new HttpError(403, 'forbidden'));
  };

export const callerOf = (res: Response) => res.locals.caller as Caller;

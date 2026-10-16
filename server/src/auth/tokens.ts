import jwt from 'jsonwebtoken';
import { env } from '../env';

export type Role = 'chw' | 'supervisor' | 'admin';
export type AccessClaims = { sub: string; role: Role; hc: string | null };

const opts = { algorithms: ['HS256'] as jwt.Algorithm[] };

export const signAccess = (claims: AccessClaims) =>
  jwt.sign(claims, env.JWT_SECRET, { expiresIn: '15m' });

export const signRefresh = (sub: string) =>
  jwt.sign({ sub, typ: 'refresh' }, env.JWT_REFRESH_SECRET, { expiresIn: '30d' });

export function verifyAccess(token: string): AccessClaims {
  const { sub, role, hc } = jwt.verify(token, env.JWT_SECRET, opts) as AccessClaims;
  return { sub, role, hc };
}

export function verifyRefresh(token: string): string {
  const payload = jwt.verify(token, env.JWT_REFRESH_SECRET, opts) as { sub: string; typ?: string };
  if (payload.typ !== 'refresh') throw new Error('not a refresh token');
  return payload.sub;
}

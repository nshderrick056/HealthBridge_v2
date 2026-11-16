// Server side only (route handlers and proxy.ts). The API tokens live in httpOnly cookies, so
// browser JavaScript never sees them; the browser talks to /api/*, which forwards to API_URL.
import type { NextResponse } from 'next/server';

export const ACCESS_COOKIE = 'hb_access';
export const REFRESH_COOKIE = 'hb_refresh';
export const NAME_COOKIE = 'hb_name';
/** 'supervisor' or 'admin'. Only picks which pages to show; the API checks the role on every call. */
export const ROLE_COOKIE = 'hb_role';
export type DashboardRole = 'supervisor' | 'admin';

export function apiUrl() {
  const url = process.env.API_URL;
  if (!url) throw new Error('API_URL is not set');
  return url.replace(/\/+$/, '');
}

const base = {
  httpOnly: true,
  // Lax: sent on a top-level link into the dashboard, never on a cross-site PATCH.
  sameSite: 'lax' as const,
  secure: process.env.NODE_ENV === 'production',
  path: '/',
};
// A Firebase ID token lives 60 min; its cookie expires five minutes earlier so we refresh before the API says 401.
const ACCESS_MAX_AGE = 55 * 60;
const REFRESH_MAX_AGE = 30 * 24 * 3600;

export function setSession(
  res: NextResponse,
  s: { accessToken: string; refreshToken?: string; name?: string; role?: DashboardRole },
) {
  res.cookies.set(ACCESS_COOKIE, s.accessToken, { ...base, maxAge: ACCESS_MAX_AGE });
  if (s.refreshToken) res.cookies.set(REFRESH_COOKIE, s.refreshToken, { ...base, maxAge: REFRESH_MAX_AGE });
  if (s.name) res.cookies.set(NAME_COOKIE, s.name, { ...base, maxAge: REFRESH_MAX_AGE });
  if (s.role) res.cookies.set(ROLE_COOKIE, s.role, { ...base, maxAge: REFRESH_MAX_AGE });
}

export function clearSession(res: NextResponse) {
  for (const name of [ACCESS_COOKIE, REFRESH_COOKIE, NAME_COOKIE, ROLE_COOKIE]) {
    res.cookies.set(name, '', { ...base, maxAge: 0 });
  }
}

/** Where a role starts. A session from before the role cookie existed is a supervisor's. */
export const homeOf = (role: string | undefined) => (role === 'admin' ? '/admin/resets' : '/alerts');

// Sign-in is Firebase Auth (project healthbridge-rwanda). Its web API key is public (it is in the
// Android app too); it identifies the project, it does not grant access.
function firebaseKey() {
  const key = process.env.FIREBASE_WEB_API_KEY;
  if (!key) throw new Error('FIREBASE_WEB_API_KEY is not set');
  return key;
}

export type FirebaseSignIn =
  | { ok: true; idToken: string; refreshToken: string; name: string; role: string | null; mustChange: boolean }
  | { ok: false; status: number; error: string };

/** Email + password sign-in with Firebase Auth. The role comes from the token's custom claims. */
export async function firebaseSignIn(email: string, password: string): Promise<FirebaseSignIn> {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseKey()}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
    cache: 'no-store',
  });
  const body = (await res.json().catch(() => ({}))) as {
    idToken?: string;
    refreshToken?: string;
    displayName?: string;
    error?: { message?: string };
  };
  if (!res.ok || !body.idToken || !body.refreshToken) {
    const message = body.error?.message ?? '';
    if (message.startsWith('TOO_MANY_ATTEMPTS')) return { ok: false, status: 429, error: 'too_many_attempts' };
    if (message.startsWith('USER_DISABLED')) return { ok: false, status: 403, error: 'account_disabled' };
    return { ok: false, status: 401, error: 'invalid_credentials' };
  }
  return {
    ok: true,
    idToken: body.idToken,
    refreshToken: body.refreshToken,
    name: body.displayName ?? '',
    role: claimsOf(body.idToken).role ?? null,
    mustChange: claimsOf(body.idToken).mc === true,
  };
}

/** The token's claims. Read only to choose what to show: the API verifies the token on every call. */
function claimsOf(idToken: string): { role?: string; mc?: boolean } {
  try {
    return JSON.parse(Buffer.from(idToken.split('.')[1], 'base64url').toString()) as { role?: string; mc?: boolean };
  } catch {
    return {};
  }
}

/** A new ID token, or null when the refresh token is expired, revoked or the user disabled. */
export async function refreshAccess(refreshToken: string): Promise<string | null> {
  const res = await fetch(`https://securetoken.googleapis.com/v1/token?key=${firebaseKey()}`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: refreshToken }).toString(),
    cache: 'no-store',
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { id_token?: string };
  return body.id_token ?? null;
}

// Server side only (route handlers and proxy.ts). The API tokens live in httpOnly cookies, so
// browser JavaScript never sees them; the browser talks to /api/*, which forwards to API_URL.
import type { NextResponse } from 'next/server';

export const ACCESS_COOKIE = 'hb_access';
export const REFRESH_COOKIE = 'hb_refresh';
export const NAME_COOKIE = 'hb_name';

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
// The access token lives 15 min; its cookie expires a minute earlier so we refresh before the API says 401.
const ACCESS_MAX_AGE = 14 * 60;
const REFRESH_MAX_AGE = 30 * 24 * 3600;

export function setSession(res: NextResponse, s: { accessToken: string; refreshToken?: string; name?: string }) {
  res.cookies.set(ACCESS_COOKIE, s.accessToken, { ...base, maxAge: ACCESS_MAX_AGE });
  if (s.refreshToken) res.cookies.set(REFRESH_COOKIE, s.refreshToken, { ...base, maxAge: REFRESH_MAX_AGE });
  if (s.name) res.cookies.set(NAME_COOKIE, s.name, { ...base, maxAge: REFRESH_MAX_AGE });
}

export function clearSession(res: NextResponse) {
  for (const name of [ACCESS_COOKIE, REFRESH_COOKIE, NAME_COOKIE]) res.cookies.set(name, '', { ...base, maxAge: 0 });
}

/** A new access token, or null when the refresh token is expired, revoked or the user deactivated. */
export async function refreshAccess(refreshToken: string): Promise<string | null> {
  const res = await fetch(`${apiUrl()}/auth/refresh`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
    cache: 'no-store',
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { accessToken?: string };
  return body.accessToken ?? null;
}

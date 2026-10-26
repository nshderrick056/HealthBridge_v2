import { NextResponse, type NextRequest } from 'next/server';
import { ACCESS_COOKIE, apiUrl, clearSession, refreshAccess, REFRESH_COOKIE, setSession } from './session';

// Only the supervisor routes are reachable through the dashboard; anything else is a 404 here.
const ROUTES: { method: string; path: RegExp }[] = [
  { method: 'GET', path: /^alerts$/ },
  { method: 'GET', path: /^alerts\/[0-9a-f-]{36}$/ },
  { method: 'PATCH', path: /^alerts\/[0-9a-f-]{36}$/ },
  { method: 'GET', path: /^chws$/ },
];

const json = (body: unknown, status: number) =>
  NextResponse.json(body, { status, headers: { 'cache-control': 'no-store' } });

/** Forwards /api/<path> to the API with the session's bearer token, refreshing it once on expiry. */
export async function forward(req: NextRequest, path: string[]) {
  const target = path.join('/');
  if (!ROUTES.some((r) => r.method === req.method && r.path.test(target))) return json({ error: 'not_found' }, 404);

  const access = req.cookies.get(ACCESS_COOKIE)?.value;
  const refresh = req.cookies.get(REFRESH_COOKIE)?.value;
  const body = req.method === 'GET' ? undefined : await req.text();

  const call = (token: string) =>
    fetch(`${apiUrl()}/${target}${req.nextUrl.search}`, {
      method: req.method,
      headers: { authorization: `Bearer ${token}`, ...(body ? { 'content-type': 'application/json' } : {}) },
      body,
      cache: 'no-store',
    });

  let upstream: Response | null = null;
  let renewed: string | null = null;
  try {
    if (access) upstream = await call(access);
    if ((!upstream || upstream.status === 401) && refresh) {
      renewed = await refreshAccess(refresh);
      if (renewed) upstream = await call(renewed);
    }
  } catch {
    return json({ error: 'api_unreachable' }, 502);
  }

  if (!upstream || upstream.status === 401) {
    const out = json({ error: 'unauthorized' }, 401);
    clearSession(out);
    return out;
  }
  const out = new NextResponse(await upstream.text(), {
    status: upstream.status,
    headers: {
      'content-type': upstream.headers.get('content-type') ?? 'application/json',
      'cache-control': 'no-store',
    },
  });
  if (renewed) setSession(out, { accessToken: renewed });
  return out;
}

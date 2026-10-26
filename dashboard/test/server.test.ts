// @vitest-environment node
import { NextRequest } from 'next/server';
import { describe, expect, it } from 'vitest';
import { POST as login } from '@/app/api/auth/login/route';
import { POST as logout } from '@/app/api/auth/logout/route';
import { forward } from '@/lib/proxy';
import { proxy } from '@/proxy';
import { json, mockFetch } from './helpers';

const request = (path: string, init: { method?: string; cookie?: string; body?: string } = {}) =>
  new NextRequest(`http://dash.test${path}`, {
    method: init.method ?? 'GET',
    headers: init.cookie ? { cookie: init.cookie } : {},
    body: init.body,
  });

const authHeader = (init?: RequestInit) => new Headers(init?.headers).get('authorization');

describe('API proxy', () => {
  it('forwards an allowed route with the access token from the cookie', async () => {
    const fetch = mockFetch(() => json({ alerts: [] }));
    const res = await forward(request('/api/alerts?status=new', { cookie: 'hb_access=A1; hb_refresh=R1' }), ['alerts']);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ alerts: [] });
    expect(fetch).toHaveBeenCalledOnce();
    expect(fetch.mock.calls[0][0]).toBe('http://api.test/alerts?status=new');
    expect(authHeader(fetch.mock.calls[0][1])).toBe('Bearer A1');
    expect(res.headers.get('set-cookie')).toBeNull();
  });

  it('refuses routes the dashboard does not use, without calling the API', async () => {
    const fetch = mockFetch(() => json({}));
    const cookie = 'hb_access=A1';
    expect((await forward(request('/api/auth/login', { cookie }), ['auth', 'login'])).status).toBe(404);
    expect((await forward(request('/api/sync/pull', { cookie }), ['sync', 'pull'])).status).toBe(404);
    expect((await forward(request('/api/chws', { method: 'PATCH', cookie, body: '{}' }), ['chws'])).status).toBe(404);
    expect((await forward(request('/api/alerts/../auth', { cookie }), ['alerts', '..', 'auth'])).status).toBe(404);
    expect(fetch).not.toHaveBeenCalled();
  });

  it('refreshes an expired access token once, retries, and stores the new token', async () => {
    const fetch = mockFetch((url, init) => {
      if (url.endsWith('/auth/refresh')) return json({ accessToken: 'A2' });
      return authHeader(init) === 'Bearer A2' ? json({ chws: [] }) : json({ error: 'unauthorized' }, 401);
    });
    const res = await forward(request('/api/chws', { cookie: 'hb_access=OLD; hb_refresh=R1' }), ['chws']);

    expect(res.status).toBe(200);
    expect(fetch.mock.calls.map(([u]) => u)).toEqual(['http://api.test/chws', 'http://api.test/auth/refresh', 'http://api.test/chws']);
    expect(JSON.parse(String(fetch.mock.calls[1][1]?.body))).toEqual({ refreshToken: 'R1' });
    expect(res.cookies.get('hb_access')?.value).toBe('A2');
    expect(res.headers.get('set-cookie')).toMatch(/HttpOnly/i);
  });

  it('refreshes straight away when the access cookie has expired', async () => {
    const fetch = mockFetch((url) => (url.endsWith('/auth/refresh') ? json({ accessToken: 'A2' }) : json({ chws: [] })));
    await forward(request('/api/chws', { cookie: 'hb_refresh=R1' }), ['chws']);
    expect(fetch.mock.calls.map(([u]) => u)).toEqual(['http://api.test/auth/refresh', 'http://api.test/chws']);
  });

  it('ends the session when the refresh token is rejected', async () => {
    mockFetch((url) => json({ error: url.endsWith('/auth/refresh') ? 'invalid_token' : 'unauthorized' }, 401));
    const res = await forward(request('/api/chws', { cookie: 'hb_access=OLD; hb_refresh=R1' }), ['chws']);
    expect(res.status).toBe(401);
    expect(res.cookies.get('hb_refresh')?.value).toBe('');
  });

  it('passes a PATCH body and the API status through', async () => {
    const fetch = mockFetch(() => json({ error: 'status_changed' }, 409));
    const id = '6f0c1c1e-0000-4000-8000-000000000001';
    const body = JSON.stringify({ status: 'reviewed' });
    const res = await forward(request(`/api/alerts/${id}`, { method: 'PATCH', cookie: 'hb_access=A1', body }), ['alerts', id]);
    expect(res.status).toBe(409);
    expect(fetch.mock.calls[0][1]).toMatchObject({ method: 'PATCH', body });
  });

  it('answers 502 when the API is down', async () => {
    mockFetch(() => {
      throw new TypeError('fetch failed');
    });
    expect((await forward(request('/api/chws', { cookie: 'hb_access=A1' }), ['chws'])).status).toBe(502);
  });
});

describe('login and logout', () => {
  const credentials = JSON.stringify({ email: 'supervisor@example.test', password: 'long-enough' });
  const loginOk = (role: string) =>
    json({ accessToken: 'A1', refreshToken: 'R1', user: { role, fullName: 'Demo Supervisor' } });

  it('keeps a supervisor\'s tokens in httpOnly cookies, not in the response body', async () => {
    const fetch = mockFetch(() => loginOk('supervisor'));
    const res = await login(request('/api/auth/login', { method: 'POST', body: credentials }));

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ name: 'Demo Supervisor' });
    expect(fetch.mock.calls[0][0]).toBe('http://api.test/auth/login');
    expect(res.cookies.get('hb_access')).toMatchObject({ value: 'A1', httpOnly: true, sameSite: 'lax' });
    expect(res.cookies.get('hb_refresh')).toMatchObject({ value: 'R1', httpOnly: true });
  });

  it('gives a CHW account no session', async () => {
    mockFetch(() => loginOk('chw'));
    const res = await login(request('/api/auth/login', { method: 'POST', body: credentials }));
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: 'not_supervisor' });
    expect(res.cookies.get('hb_access')).toBeUndefined();
  });

  it('passes the API error through and checks the body first', async () => {
    mockFetch(() => json({ error: 'invalid_credentials' }, 401));
    const bad = await login(request('/api/auth/login', { method: 'POST', body: credentials }));
    expect(bad.status).toBe(401);
    expect(await bad.json()).toEqual({ error: 'invalid_credentials' });

    const fetch = mockFetch(() => json({}));
    expect((await login(request('/api/auth/login', { method: 'POST', body: '{"email":1}' }))).status).toBe(400);
    expect(fetch).not.toHaveBeenCalled();
  });

  it('logout clears the cookies and goes to /login', async () => {
    const res = logout(request('/api/auth/logout', { method: 'POST', cookie: 'hb_access=A1; hb_refresh=R1' }));
    expect(res.status).toBe(303);
    expect(res.headers.get('location')).toBe('http://dash.test/login');
    expect(res.cookies.get('hb_refresh')?.value).toBe('');
  });

  it('pages without a session redirect to /login', () => {
    expect(proxy(request('/alerts')).headers.get('location')).toBe('http://dash.test/login');
    expect(proxy(request('/alerts', { cookie: 'hb_refresh=R1' })).headers.get('location')).toBeNull();
  });
});

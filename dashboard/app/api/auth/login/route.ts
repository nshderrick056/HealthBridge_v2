import { NextResponse, type NextRequest } from 'next/server';
import { apiUrl, setSession } from '@/lib/session';

type LoginResponse = {
  accessToken: string;
  refreshToken: string;
  user: { role: string; fullName: string };
  error?: string;
};

export async function POST(req: NextRequest) {
  const body = (await req.json().catch(() => null)) as { email?: unknown; password?: unknown } | null;
  const { email, password } = body ?? {};
  if (typeof email !== 'string' || typeof password !== 'string' || !email || !password) {
    return NextResponse.json({ error: 'invalid_request' }, { status: 400 });
  }

  let res: Response;
  try {
    res = await fetch(`${apiUrl()}/auth/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password }),
      cache: 'no-store',
    });
  } catch {
    return NextResponse.json({ error: 'api_unreachable' }, { status: 502 });
  }
  const data = (await res.json().catch(() => ({}))) as Partial<LoginResponse>;
  if (!res.ok) return NextResponse.json({ error: data.error ?? 'login_failed' }, { status: res.status });
  // CHWs log in with phone + PIN in the app; an email account that is not a supervisor gets no session here.
  if (data.user?.role !== 'supervisor' || !data.accessToken || !data.refreshToken) {
    return NextResponse.json({ error: 'not_supervisor' }, { status: 403 });
  }

  const out = NextResponse.json({ name: data.user.fullName });
  setSession(out, { accessToken: data.accessToken, refreshToken: data.refreshToken, name: data.user.fullName });
  return out;
}

import { NextResponse, type NextRequest } from 'next/server';
import { firebaseSignIn, setSession } from '@/lib/session';

export async function POST(req: NextRequest) {
  const body = (await req.json().catch(() => null)) as { email?: unknown; password?: unknown } | null;
  const { email, password } = body ?? {};
  if (typeof email !== 'string' || typeof password !== 'string' || !email || !password) {
    return NextResponse.json({ error: 'invalid_request' }, { status: 400 });
  }

  let signIn: Awaited<ReturnType<typeof firebaseSignIn>>;
  try {
    signIn = await firebaseSignIn(email, password);
  } catch {
    return NextResponse.json({ error: 'api_unreachable' }, { status: 502 });
  }
  if (!signIn.ok) return NextResponse.json({ error: signIn.error }, { status: signIn.status });
  // CHWs and admins use the mobile app; only supervisors get a dashboard session.
  if (signIn.role !== 'supervisor') {
    return NextResponse.json({ error: 'not_supervisor' }, { status: 403 });
  }
  // Still the temporary password from the admin's SMS: it is replaced in the app first.
  if (signIn.mustChange) return NextResponse.json({ error: 'must_change' }, { status: 403 });

  const out = NextResponse.json({ name: signIn.name });
  setSession(out, { accessToken: signIn.idToken, refreshToken: signIn.refreshToken, name: signIn.name });
  return out;
}

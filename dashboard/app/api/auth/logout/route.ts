import { NextResponse, type NextRequest } from 'next/server';
import { clearSession } from '@/lib/session';

// A plain form POST, so logging out works without JavaScript. 303 turns it into a GET of /login.
export function POST(req: NextRequest) {
  const out = NextResponse.redirect(new URL('/login', req.url), 303);
  clearSession(out);
  return out;
}

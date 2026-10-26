import { NextResponse, type NextRequest } from 'next/server';
import { REFRESH_COOKIE } from '@/lib/session';

// Pages need a session; /api/* answers 401 on its own and the client sends the user to /login.
export function proxy(req: NextRequest) {
  if (!req.cookies.has(REFRESH_COOKIE)) return NextResponse.redirect(new URL('/login', req.url));
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!login|api|_next/static|_next/image|favicon.ico).*)'],
};

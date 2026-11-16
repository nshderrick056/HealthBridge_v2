import { NextResponse, type NextRequest } from 'next/server';
import { homeOf, REFRESH_COOKIE, ROLE_COOKIE } from '@/lib/session';

// Pages need a session, and each role stays on its own pages; /api/* answers 401 on its own and the
// client sends the user to /login. The role cookie only routes: the API checks the role on every call.
export function proxy(req: NextRequest) {
  if (!req.cookies.has(REFRESH_COOKIE)) return NextResponse.redirect(new URL('/login', req.url));
  const role = req.cookies.get(ROLE_COOKIE)?.value;
  const adminPage = req.nextUrl.pathname === '/admin' || req.nextUrl.pathname.startsWith('/admin/');
  if (adminPage !== (role === 'admin')) return NextResponse.redirect(new URL(homeOf(role), req.url));
  return NextResponse.next();
}

export const config = {
  // `/` is left to app/page.tsx, which sends each role home.
  matcher: ['/((?!login|api|_next/static|_next/image|favicon.ico).+)'],
};

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { homeOf, ROLE_COOKIE } from '@/lib/session';

/** Sends each role to its first page (the proxy sends anyone without a session on to /login). */
export default async function Home() {
  redirect(homeOf((await cookies()).get(ROLE_COOKIE)?.value));
}

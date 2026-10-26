import { cookies } from 'next/headers';
import type { ReactNode } from 'react';
import { NavLinks } from '@/components/NavLinks';
import { NAME_COOKIE } from '@/lib/session';

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const name = (await cookies()).get(NAME_COOKIE)?.value;
  return (
    <>
      <header className="border-b border-line bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <div className="flex items-center gap-4">
            <span className="font-bold text-teal">HealthBridge</span>
            <NavLinks />
          </div>
          <div className="flex items-center gap-3 text-sm">
            {name && <span className="hidden text-muted sm:inline">{name}</span>}
            <form action="/api/auth/logout" method="post">
              <button type="submit" className="rounded-full border border-line px-3.5 py-1.5 font-semibold text-teal hover:border-teal">
                Sign out
              </button>
            </form>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">{children}</main>
    </>
  );
}

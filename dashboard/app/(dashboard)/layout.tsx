import { cookies } from 'next/headers';
import type { ReactNode } from 'react';
import { NavLinks } from '@/components/NavLinks';
import { NAME_COOKIE } from '@/lib/session';

const initials = (name: string) =>
  name
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((p) => p[0])
    .filter((_, i, a) => i === 0 || i === a.length - 1)
    .join('')
    .toUpperCase();

function SignOut({ dark = true }: { dark?: boolean }) {
  return (
    <form action="/api/auth/logout" method="post">
      <button
        type="submit"
        className={`min-h-11 rounded-full px-3 text-sm underline underline-offset-4 ${dark ? 'text-side hover:text-white' : 'text-muted'}`}
      >
        Sign out
      </button>
    </form>
  );
}

/** Dark sidebar on wide screens (Figma "Web dashboards (v3)"), a dark top bar on phones. */
export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const name = (await cookies()).get(NAME_COOKIE)?.value;
  return (
    <div className="lg:flex">
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col bg-ink px-5 pt-8 pb-6 lg:flex">
        <p className="text-[22px] font-semibold tracking-tight text-lime">HealthBridge</p>
        <p className="text-[15px] text-side">Supervisor</p>
        <div className="mt-8 flex-1">
          <NavLinks vertical />
        </div>
        {name && (
          <div className="flex items-center gap-3">
            <span
              aria-hidden
              className="flex size-10 shrink-0 items-center justify-center rounded-full bg-lime text-[15px] font-semibold text-ink"
            >
              {initials(name)}
            </span>
            <div className="min-w-0">
              <p className="truncate text-[15px] font-semibold text-white">{name}</p>
              <SignOut />
            </div>
          </div>
        )}
        {!name && <SignOut />}
      </aside>

      <header className="bg-ink px-4 pt-4 pb-3 lg:hidden">
        <div className="flex items-center justify-between">
          <span className="text-lg font-semibold text-lime">HealthBridge</span>
          <SignOut />
        </div>
        <div className="mt-2">
          <NavLinks />
        </div>
      </header>

      <main className="min-w-0 flex-1 px-4 py-6 sm:px-8 lg:px-10 lg:py-9">
        <div className="mx-auto max-w-6xl">{children}</div>
      </main>
    </div>
  );
}

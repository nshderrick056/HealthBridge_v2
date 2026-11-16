import { cookies } from 'next/headers';
import type { ReactNode } from 'react';
import { NAME_COOKIE } from '@/lib/session';
import { NavLinks, type Section } from './NavLinks';

const initials = (name: string) => {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
};

function SignOut() {
  return (
    <form action="/api/auth/logout" method="post">
      <button type="submit" className="min-h-11 rounded-full text-sm text-side underline underline-offset-4 hover:text-white">
        Sign out
      </button>
    </form>
  );
}

/** Dark sidebar on wide screens (Figma "Web dashboards (v3)"), a dark top bar on phones. */
export async function Shell({ section, children }: { section: Section; children: ReactNode }) {
  const name = (await cookies()).get(NAME_COOKIE)?.value;
  return (
    <div className="lg:flex">
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col bg-ink px-5 pt-8 pb-6 lg:flex">
        <p className="text-[22px] font-semibold tracking-tight text-lime">HealthBridge</p>
        <p className="text-[15px] text-side">{section === 'admin' ? 'Admin' : 'Supervisor'}</p>
        <div className="mt-8 flex-1">
          <NavLinks section={section} vertical />
        </div>
        {name ? (
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
        ) : (
          <SignOut />
        )}
      </aside>

      <header className="bg-ink px-4 pt-4 pb-3 lg:hidden">
        <div className="flex items-center justify-between">
          <span className="text-lg font-semibold text-lime">HealthBridge</span>
          <SignOut />
        </div>
        <div className="mt-2">
          <NavLinks section={section} />
        </div>
      </header>

      <main className="min-w-0 flex-1 px-4 py-6 sm:px-8 lg:px-10 lg:py-9">
        <div className="mx-auto max-w-6xl">{children}</div>
      </main>
    </div>
  );
}

'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { AlertIcon, UserIcon } from './icons';

const LINKS = [
  { href: '/alerts', label: 'Urgent alerts', short: 'Alerts', Icon: AlertIcon },
  { href: '/chws', label: 'Community health workers', short: 'CHWs', Icon: UserIcon },
];

/** The dark sidebar's links; the current one is a lime pill. Horizontal in the phone top bar. */
export function NavLinks({ vertical = false }: { vertical?: boolean }) {
  const path = usePathname();
  return (
    <nav aria-label="Main" className={vertical ? 'flex flex-col gap-1' : 'flex gap-1 overflow-x-auto'}>
      {LINKS.map(({ href, label, short, Icon }) => {
        const active = path === href || path.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? 'page' : undefined}
            className={`flex min-h-11 shrink-0 items-center gap-3 rounded-full px-4 py-2.5 text-[15px] ${
              active ? 'bg-lime font-semibold text-ink' : 'text-white hover:bg-white/10'
            }`}
          >
            <span className={active ? 'text-ink' : 'text-side'}>
              <Icon />
            </span>
            {vertical ? label : short}
          </Link>
        );
      })}
    </nav>
  );
}

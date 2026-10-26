'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LINKS = [
  { href: '/alerts', label: 'Alerts' },
  { href: '/chws', label: 'CHWs' },
];

export function NavLinks() {
  const path = usePathname();
  return (
    <nav aria-label="Main" className="flex gap-1">
      {LINKS.map(({ href, label }) => {
        const active = path === href || path.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? 'page' : undefined}
            className={`rounded-full px-3.5 py-1.5 text-sm font-semibold ${active ? 'bg-teal-tint text-teal' : 'text-muted hover:text-ink'}`}
          >
            {label}
          </Link>
        );
      })}
    </nav>
  );
}

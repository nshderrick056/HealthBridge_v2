'use client';
import Link from 'next/link';
import { useState } from 'react';
import type { Member } from '@/lib/admin';
import { Avatar } from '../badges';
import { ChevronIcon } from '../icons';
import { usePolling } from '../usePolling';

const TABS = [
  { role: 'chw', label: 'CHWs' },
  { role: 'supervisor', label: 'Supervisors' },
] as const;

/** Every CHW or supervisor in two tabs; a member opens their own page. */
export function Members() {
  const [role, setRole] = useState<'chw' | 'supervisor'>('chw');
  const { data, error } = usePolling<{ members: Member[] }>(`admin/users?role=${role}`, 60_000);

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Members</h1>
          <p className="mt-1 max-w-3xl text-muted">
            Click a member to see their details, switch their account off, or delete it.
          </p>
        </div>
        <Link
          href="/admin/members/new"
          className="inline-flex min-h-12 items-center rounded-full bg-ink px-6 font-semibold text-white hover:bg-brand-deep"
        >
          Add a member
        </Link>
      </header>

      <div role="tablist" aria-label="Member type" className="flex gap-2">
        {TABS.map((t) => (
          <button
            key={t.role}
            type="button"
            role="tab"
            aria-selected={role === t.role}
            onClick={() => setRole(t.role)}
            className={`min-h-11 rounded-full px-5 text-[15px] ${
              role === t.role ? 'bg-ink font-semibold text-white' : 'bg-white text-ink shadow-card hover:bg-teal-tint'
            }`}
          >
            {t.label}
            {data && role === t.role && <span className="ml-2 text-white/75">{data.members.length}</span>}
          </button>
        ))}
      </div>

      {error && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load the members. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && data.members.length === 0 && (
        <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">
          No {role === 'chw' ? 'CHWs' : 'supervisors'} yet.
        </p>
      )}
      {data && data.members.length > 0 && (
        <ul role="tabpanel" className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
          {data.members.map((m) => (
            <li key={m.id}>
              <Link href={`/admin/members/${m.id}`} className="flex items-center gap-4 px-5 py-4 hover:bg-canvas sm:px-6">
                <Avatar name={m.fullName} tone={m.active ? 'plain' : 'due'} />
                <div className="min-w-0 flex-1">
                  <p className="text-[17px] font-semibold">
                    {m.fullName}
                    {!m.active && (
                      <span className="ml-2 rounded-full bg-amber-tint px-2.5 py-0.5 text-sm font-semibold text-warning">
                        Switched off
                      </span>
                    )}
                  </p>
                  <p className="text-[15px] text-muted">
                    {[m.phone, m.village, m.healthCenterName].filter(Boolean).join(' · ')}
                  </p>
                </div>
                <span className="text-chevron" aria-hidden>
                  <ChevronIcon />
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

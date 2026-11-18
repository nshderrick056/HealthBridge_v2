'use client';
import Link from 'next/link';
import type { ReactNode } from 'react';
import type { CentreDetails } from '@/lib/admin';
import { Avatar } from '../badges';
import { ChevronIcon } from '../icons';
import { usePolling } from '../usePolling';

const ROLE = { chw: 'CHW', supervisor: 'Supervisor' };

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-wrap justify-between gap-x-6 gap-y-1 px-5 py-3.5 sm:px-6">
      <dt className="text-muted">{label}</dt>
      <dd className="font-medium">{children}</dd>
    </div>
  );
}

/** One health centre: its details and the CHWs and supervisors who belong to it. */
export function CentreDetail({ id }: { id: string }) {
  const { data, error } = usePolling<CentreDetails>(`admin/health-centers/${id}`, 60_000);
  return (
    <div className="space-y-6">
      <Link
        href="/admin/centres"
        className="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-4 text-[15px] font-medium shadow-card hover:bg-teal-tint"
      >
        <span aria-hidden>←</span> All health centres
      </Link>
      {error === 'not_found' && (
        <p className="rounded-3xl bg-white p-8 text-center text-muted shadow-card">This health centre no longer exists.</p>
      )}
      {error && error !== 'not_found' && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load this health centre. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && (
        <>
          <header>
            <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">{data.name}</h1>
            <p className="mt-1 text-muted">{[data.district, data.sector].filter(Boolean).join(' · ') || 'No location set'}</p>
          </header>
          <dl className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
            <Row label="District">{data.district ?? '—'}</Row>
            <Row label="Sector">{data.sector ?? '—'}</Row>
            <Row label="Call number">
              {data.callNumber ? (
                <a href={`tel:${data.callNumber}`} className="text-brand underline underline-offset-4">
                  {data.callNumber}
                </a>
              ) : (
                <span className="text-warning">Not set: CHWs cannot call from an urgent alert</span>
              )}
            </Row>
          </dl>

          <section aria-labelledby="members" className="space-y-3">
            <h2 id="members" className="text-xl font-semibold tracking-tight">
              Members <span className="font-normal text-muted">{data.members.length}</span>
            </h2>
            {data.members.length === 0 ? (
              <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">
                No one belongs to this health centre yet.
              </p>
            ) : (
              <ul className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
                {data.members.map((m) => (
                  <li key={m.id}>
                    <Link href={`/admin/members/${m.id}`} className="flex items-center gap-4 px-5 py-4 hover:bg-canvas sm:px-6">
                      <Avatar name={m.fullName} tone={m.active ? 'plain' : 'due'} />
                      <div className="min-w-0 flex-1">
                        <p className="text-[17px] font-semibold">
                          {m.fullName}
                          {!m.active && <span className="ml-2 text-sm font-semibold text-warning">Switched off</span>}
                        </p>
                        <p className="text-[15px] text-muted">{[ROLE[m.role], m.phone].join(' · ')}</p>
                      </div>
                      <span className="text-chevron" aria-hidden>
                        <ChevronIcon />
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </>
      )}
    </div>
  );
}

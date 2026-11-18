'use client';
import Link from 'next/link';
import type { ChwHistory as Data } from '@/lib/history';
import { Avatar } from './badges';
import { usePolling } from './usePolling';
import { VisitHistory } from './VisitHistory';

const ROLE: Record<string, string> = { asm: 'ASM', binome: 'Binôme' };

/** One CHW and every visit they recorded, newest first. */
export function ChwHistory({ id }: { id: string }) {
  const { data, error } = usePolling<Data>(`chws/${id}`, 60_000);
  return (
    <div className="space-y-6">
      <Link
        href="/chws"
        className="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-4 text-[15px] font-medium shadow-card hover:bg-teal-tint"
      >
        <span aria-hidden>←</span> All CHWs
      </Link>
      {error === 'not_found' && (
        <p className="rounded-3xl bg-white p-8 text-center text-muted shadow-card">
          This CHW does not exist or belongs to another health centre.
        </p>
      )}
      {error && error !== 'not_found' && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load this CHW. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && (
        <>
          <header className="flex items-center gap-4">
            <Avatar name={data.chw.name} tone="lime" />
            <div>
              <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">{data.chw.name}</h1>
              <p className="mt-1 text-muted">
                {[data.chw.chwRole ? ROLE[data.chw.chwRole] : null, data.chw.village].filter(Boolean).join(' · ')}
                {' · '}
                <a href={`tel:${data.chw.phone}`} className="text-brand underline underline-offset-4">
                  {data.chw.phone}
                </a>
              </p>
            </div>
          </header>
          <section aria-labelledby="visits" className="space-y-3">
            <h2 id="visits" className="text-xl font-semibold tracking-tight">
              Visits <span className="font-normal text-muted">{data.visits.length}</span>
            </h2>
            <VisitHistory visits={data.visits} showPatient />
          </section>
        </>
      )}
    </div>
  );
}

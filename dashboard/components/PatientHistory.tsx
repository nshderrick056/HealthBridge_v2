'use client';
import Link from 'next/link';
import { ageSex, type PatientHistory as Data } from '@/lib/history';
import { Avatar } from './badges';
import { usePolling } from './usePolling';
import { VisitHistory } from './VisitHistory';

/** One patient: who they are, their CHW, and every visit with what was recorded. */
export function PatientHistory({ id }: { id: string }) {
  const { data, error } = usePolling<Data>(`patients/${id}`, 60_000);
  const urgent = data?.visits[0]?.isUrgent ?? false;
  return (
    <div className="space-y-6">
      <Link
        href="/patients"
        className="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-4 text-[15px] font-medium shadow-card hover:bg-teal-tint"
      >
        <span aria-hidden>←</span> All patients
      </Link>
      {error === 'not_found' && (
        <p className="rounded-3xl bg-white p-8 text-center text-muted shadow-card">
          This patient does not exist or belongs to another health centre.
        </p>
      )}
      {error && error !== 'not_found' && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load this patient. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && (
        <>
          <section
            className={`rounded-3xl p-6 text-white sm:p-8 ${urgent ? 'bg-red' : 'bg-gradient-to-br from-brand to-brand-light'}`}
          >
            <div className="flex items-center gap-4">
              <Avatar name={data.patient.name ?? data.patient.shortId ?? '?'} tone="lime" />
              <div>
                <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
                  {data.patient.name ?? 'Name not received yet'}
                </h1>
                <p className={`mt-1 text-[15px] ${urgent ? 'text-on-red' : 'text-on-brand'}`}>
                  {[ageSex(data.patient), data.patient.village, data.patient.shortId].filter(Boolean).join(' · ')}
                  {data.patient.archived && ' · archived by the CHW'}
                </p>
              </div>
            </div>
            {urgent && <p className="mt-4 font-semibold">The latest visit was urgent.</p>}
          </section>
          <section className="rounded-3xl bg-white p-5 shadow-card sm:p-6">
            <h2 className="text-xl font-semibold tracking-tight">Community health worker</h2>
            <p className="mt-2 text-[17px]">
              <Link href={`/chws/${data.chw.id}`} className="font-semibold text-brand underline underline-offset-4">
                {data.chw.name ?? 'Unknown'}
              </Link>
              {data.chw.phone && (
                <>
                  {' · '}
                  <a href={`tel:${data.chw.phone}`} className="text-brand underline underline-offset-4">
                    {data.chw.phone}
                  </a>
                </>
              )}
            </p>
          </section>
          <section aria-labelledby="visits" className="space-y-3">
            <h2 id="visits" className="text-xl font-semibold tracking-tight">
              Visits <span className="font-normal text-muted">{data.visits.length}</span>
            </h2>
            <VisitHistory visits={data.visits} />
          </section>
        </>
      )}
    </div>
  );
}

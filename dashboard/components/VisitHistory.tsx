'use client';
import Link from 'next/link';
import { formatDate, formatDateTime, VISIT_TYPE_LABEL } from '@/lib/format';
import type { HistoryVisit } from '@/lib/history';

/** Visits newest first, each with everything recorded. `showPatient` links each one to its patient. */
export function VisitHistory({ visits, showPatient = false }: { visits: HistoryVisit[]; showPatient?: boolean }) {
  if (visits.length === 0) {
    return <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">No visits recorded yet.</p>;
  }
  return (
    <ol className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
      {visits.map((v) => (
        <li key={v.id} className="px-5 py-4 sm:px-6">
          <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-1">
            <div className="min-w-0">
              <p className="text-[17px] font-semibold">
                {v.type ? VISIT_TYPE_LABEL[v.type] : 'Visit'}
                {v.recordedAt && <span className="ml-2 font-normal text-muted">{formatDateTime(v.recordedAt)}</span>}
              </p>
              {showPatient && v.patient && (
                <Link href={`/patients/${v.patient.id}`} className="text-[15px] text-brand underline underline-offset-4">
                  {v.patient.name ?? `Patient ${v.patient.shortId ?? ''}`}
                </Link>
              )}
            </div>
            <span className="flex flex-wrap gap-2">
              {v.isUrgent && (
                <span className="rounded-full bg-red-tint px-3 py-1 text-sm font-semibold text-red">Urgent</span>
              )}
              {v.isPartial && (
                <span className="rounded-full bg-amber-tint px-3 py-1 text-sm font-semibold text-warning">
                  SMS only, full record pending
                </span>
              )}
            </span>
          </div>
          {v.dangerSigns.length > 0 && (
            <p className="mt-1 text-[15px] font-medium text-red">{v.dangerSigns.join(' · ')}</p>
          )}
          <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-[15px]">
            {v.temperature != null && (
              <>
                <dt className="text-muted">Temperature</dt>
                <dd>{v.temperature} °C</dd>
              </>
            )}
            {v.condition && (
              <>
                <dt className="text-muted">Condition</dt>
                <dd>{v.condition}</dd>
              </>
            )}
            {v.symptoms && (
              <>
                <dt className="text-muted">Symptoms</dt>
                <dd className="whitespace-pre-line">{v.symptoms}</dd>
              </>
            )}
            {v.notes && (
              <>
                <dt className="text-muted">Notes</dt>
                <dd className="whitespace-pre-line">{v.notes}</dd>
              </>
            )}
            {v.followUpOn && (
              <>
                <dt className="text-muted">Follow-up</dt>
                <dd>{formatDate(v.followUpOn)}</dd>
              </>
            )}
          </dl>
        </li>
      ))}
    </ol>
  );
}

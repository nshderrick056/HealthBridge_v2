'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { formatDateTime, timeAgo } from '@/lib/format';
import { ageSex, type PatientRow } from '@/lib/history';
import { Avatar } from './badges';
import { ChevronIcon } from './icons';
import { usePolling } from './usePolling';

/** The centre's patients, latest visit first, with a search over name, ID and village. */
export function PatientList() {
  const [text, setText] = useState('');
  const [q, setQ] = useState('');
  // Search after typing pauses, not on every key.
  useEffect(() => {
    const t = setTimeout(() => setQ(text.trim()), 300);
    return () => clearTimeout(t);
  }, [text]);
  const { data, error } = usePolling<{ patients: PatientRow[] }>(
    q ? `patients?q=${encodeURIComponent(q)}` : 'patients',
    60_000,
  );

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          Patients {data && <span className="text-xl font-normal text-muted">{data.patients.length}</span>}
        </h1>
        <p className="mt-1 text-muted">Everyone your CHWs follow, latest visit first.</p>
      </header>
      <label className="block max-w-md">
        <span className="sr-only">Search patients</span>
        <input
          type="search"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Name, patient ID or village"
          className="block min-h-12 w-full rounded-full bg-white px-5 text-base shadow-card focus:outline-2 focus:outline-brand"
        />
      </label>
      {error && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load the patients. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && data.patients.length === 0 && (
        <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">
          {q ? 'No patients match.' : 'No patients registered yet.'}
        </p>
      )}
      {data && data.patients.length > 0 && (
        <ul className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
          {data.patients.map((p) => (
            <li key={p.id}>
              <Link href={`/patients/${p.id}`} className="flex items-center gap-4 px-5 py-4 hover:bg-canvas sm:px-6">
                <Avatar name={p.name ?? p.shortId ?? '?'} tone={p.lastVisitUrgent ? 'urgent' : 'plain'} />
                <div className="min-w-0 flex-1">
                  <p className="text-[17px] font-semibold">
                    {p.name ?? 'Name not received yet'}
                    <span className="ml-2 text-[15px] font-normal text-muted">{p.shortId}</span>
                  </p>
                  <p className="text-[15px] text-muted">
                    {[ageSex(p), p.village, p.chw.name && `CHW ${p.chw.name}`].filter(Boolean).join(' · ')}
                  </p>
                </div>
                <div className="hidden text-right text-[15px] sm:block">
                  {p.lastVisitAt ? (
                    <time dateTime={p.lastVisitAt} title={formatDateTime(p.lastVisitAt)} className="text-muted">
                      {timeAgo(p.lastVisitAt)}
                    </time>
                  ) : (
                    <span className="text-muted">No visits</span>
                  )}
                  {p.lastVisitUrgent && <p className="font-semibold text-red">Urgent</p>}
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

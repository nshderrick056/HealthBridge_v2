'use client';
import Link from 'next/link';
import {
  FILTER_LABEL,
  FILTERS,
  formatClock,
  formatDateTime,
  POLL_MS,
  timeAgo,
  VISIT_TYPE_LABEL,
  type Filter,
} from '@/lib/format';
import type { AlertList, AlertSummary } from '@/lib/types';
import { Avatar, ChannelBadge, PendingTag, StatusPill } from './badges';
import { ChevronIcon } from './icons';
import { usePolling } from './usePolling';

export function AlertInbox({ filter }: { filter: Filter }) {
  const query = filter === 'all' ? 'alerts' : `alerts?status=${filter}`;
  const { data, error, updatedAt } = usePolling<AlertList>(query, POLL_MS);
  const counts = data?.counts;
  const open = counts ? counts.new + counts.reviewed + counts.escalated + counts.follow_up : undefined;

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Urgent alerts</h1>
          <p className="mt-1 text-muted">Live case monitoring · refreshes every 10 seconds</p>
        </div>
        <p
          className="inline-flex items-center gap-2 rounded-full bg-white px-3.5 py-1.5 text-sm font-semibold text-brand shadow-card"
          aria-live="polite"
        >
          <span aria-hidden className="size-2 rounded-full bg-brand" />
          {updatedAt ? `Updated ${formatClock(updatedAt)}` : 'Loading…'}
        </p>
      </header>

      <section aria-label="Today at a glance" className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Tile value={open} label="Active urgent cases" urgent />
        <Tile value={counts?.new} label="Waiting for review" urgent />
        <Tile value={counts?.escalated} label="Escalated" />
        <Tile value={counts?.follow_up} label="Pending follow-ups" />
      </section>

      <nav aria-label="Filter by status" className="flex flex-wrap gap-2">
        {FILTERS.map((f) => {
          const n = f === 'open' ? open : f === 'all' || !counts ? undefined : counts[f];
          const active = f === filter;
          return (
            <Link
              key={f}
              href={f === 'open' ? '/alerts' : `/alerts?status=${f}`}
              aria-current={active ? 'page' : undefined}
              className={`inline-flex min-h-11 items-center rounded-full px-4 text-[15px] transition-colors ${
                active ? 'bg-ink font-semibold text-white' : 'bg-white text-ink shadow-card hover:bg-teal-tint'
              }`}
            >
              {FILTER_LABEL[f]}
              {n !== undefined && (
                <>
                  {' '}
                  <span className={`ml-1 ${active ? 'text-white/75' : 'text-muted'}`}>{n}</span>
                </>
              )}
            </Link>
          );
        })}
      </nav>

      {error && data && (
        <p role="status" className="rounded-2xl bg-amber-tint px-4 py-3 text-[15px] text-warning">
          Could not refresh. Showing the alerts from {formatClock(updatedAt!)}; trying again in 10 seconds.
        </p>
      )}
      {error && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load the alerts. Trying again in 10 seconds.
        </p>
      )}

      {data && data.alerts.length === 0 && (
        <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">
          No {filter === 'all' || filter === 'open' ? '' : `${FILTER_LABEL[filter].toLowerCase()} `}alerts.
        </p>
      )}
      {data && data.alerts.length > 0 && (
        <ul className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
          {data.alerts.map((a) => (
            <li key={a.id}>
              <AlertRow alert={a} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** A count and what it counts; the number is red only for cases that need action now. */
function Tile({ value, label, urgent = false }: { value?: number; label: string; urgent?: boolean }) {
  return (
    <div className="rounded-3xl bg-white p-5 shadow-card">
      <p className={`text-3xl font-semibold tracking-tight ${urgent && value ? 'text-red' : ''}`}>{value ?? '–'}</p>
      <p className="mt-0.5 text-[15px] text-muted">{label}</p>
    </div>
  );
}

const patientLabel = (a: Pick<AlertSummary, 'patient'>) => a.patient.name ?? `Patient ${a.patient.shortId}`;

function AlertRow({ alert: a }: { alert: AlertSummary }) {
  const signs = a.dangerSigns.length ? a.dangerSigns.join(' · ') : 'Urgent visit';
  const tone = a.status === 'new' || a.status === 'escalated' ? 'urgent' : a.status === 'follow_up' ? 'due' : 'plain';
  return (
    <Link
      href={`/alerts/${a.id}`}
      className="flex gap-4 px-5 py-4 transition-colors hover:bg-canvas focus-visible:-outline-offset-2 sm:px-6"
    >
      <Avatar name={a.patient.name ?? a.patient.shortId} tone={tone} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-1">
          <div className="min-w-0">
            <p className="truncate text-[17px] font-semibold">
              {patientLabel(a)}
              {a.patient.name && <span className="ml-2 text-[15px] font-normal text-muted">{a.patient.shortId}</span>}
            </p>
            <p className="text-[15px] text-red">
              {VISIT_TYPE_LABEL[a.visit.type]} · {signs}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <time dateTime={a.createdAt} title={formatDateTime(a.createdAt)} className="text-[15px] text-muted">
              {timeAgo(a.createdAt)}
            </time>
            <StatusPill status={a.status} />
          </div>
        </div>
        <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
          <span className="text-[15px] text-muted">
            CHW {a.chw.name}
            {a.village && ` · ${a.village}`}
          </span>
          <span className="flex flex-wrap items-center gap-2">
            <ChannelBadge channel={a.channel} />
            {a.isPartial && <PendingTag />}
            <span className="hidden text-chevron sm:inline" aria-hidden>
              <ChevronIcon />
            </span>
          </span>
        </div>
      </div>
    </Link>
  );
}

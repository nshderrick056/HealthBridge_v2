'use client';
import Link from 'next/link';
import type { ReactNode } from 'react';
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
import { ChannelBadge, PendingTag, StatusPill } from './badges';
import { AlertIcon, ArrowUpIcon, CalendarIcon, ChevronIcon, UserIcon } from './icons';
import { usePolling } from './usePolling';

export function AlertInbox({ filter }: { filter: Filter }) {
  const query = filter === 'all' ? 'alerts' : `alerts?status=${filter}`;
  const { data, error, updatedAt } = usePolling<AlertList>(query, POLL_MS);
  const counts = data?.counts;
  const open = counts ? counts.new + counts.reviewed + counts.escalated + counts.follow_up : undefined;

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-end justify-between gap-2">
        <div>
          <h1 className="text-2xl font-bold sm:text-3xl">Urgent alerts</h1>
          <p className="text-sm text-muted">Live case monitoring · refreshes every 10 seconds</p>
        </div>
        <p className="text-sm font-semibold text-teal" aria-live="polite">
          {updatedAt ? `Updated ${formatClock(updatedAt)}` : 'Loading…'}
        </p>
      </header>

      <section aria-label="Today at a glance" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Tile icon={<AlertIcon />} tone="bg-red-tint text-red" value={open} label="Active urgent cases" />
        <Tile icon={<UserIcon />} tone="bg-teal-tint text-teal" value={counts?.new} label="Waiting for review" />
        <Tile icon={<ArrowUpIcon />} tone="bg-amber-tint text-warning" value={counts?.escalated} label="Escalated" />
        <Tile icon={<CalendarIcon />} tone="bg-green-tint text-green" value={counts?.follow_up} label="Pending follow-ups" />
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
              className={`rounded-full border px-3.5 py-1.5 text-sm font-semibold transition-colors ${
                active ? 'border-teal bg-teal text-white' : 'border-line bg-white text-ink hover:border-teal'
              }`}
            >
              {FILTER_LABEL[f]}
              {n !== undefined && (
                <>
                  {' '}
                  <span className={active ? 'text-white/80' : 'text-muted'}>{n}</span>
                </>
              )}
            </Link>
          );
        })}
      </nav>

      {error && data && (
        <p role="status" className="rounded-xl bg-amber-tint px-4 py-3 text-sm text-warning">
          Could not refresh. Showing the alerts from {formatClock(updatedAt!)}; trying again in 10 seconds.
        </p>
      )}
      {error && !data && (
        <p role="alert" className="rounded-xl bg-red-tint px-4 py-3 text-sm text-red">
          Could not load the alerts. Trying again in 10 seconds.
        </p>
      )}

      {data && data.alerts.length === 0 && (
        <p className="rounded-2xl border border-line bg-white px-5 py-10 text-center text-muted">
          No {filter === 'all' || filter === 'open' ? '' : `${FILTER_LABEL[filter].toLowerCase()} `}alerts.
        </p>
      )}
      {data && data.alerts.length > 0 && (
        <ul className="space-y-3">
          {data.alerts.map((a) => (
            <li key={a.id}>
              <AlertCard alert={a} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function Tile({ icon, tone, value, label }: { icon: ReactNode; tone: string; value?: number; label: string }) {
  return (
    <div className="rounded-2xl border border-line bg-white p-4">
      <span className={`inline-flex size-9 items-center justify-center rounded-lg ${tone}`}>{icon}</span>
      <p className="mt-2 text-3xl font-bold">{value ?? '–'}</p>
      <p className="text-sm text-muted">{label}</p>
    </div>
  );
}

const patientLabel = (a: Pick<AlertSummary, 'patient'>) => a.patient.name ?? `Patient ${a.patient.shortId}`;

function AlertCard({ alert: a }: { alert: AlertSummary }) {
  const signs = a.dangerSigns.length ? a.dangerSigns.join(' · ') : 'Urgent visit';
  return (
    <Link
      href={`/alerts/${a.id}`}
      className={`block rounded-2xl border bg-white p-4 transition-shadow hover:shadow-md focus-visible:outline-2 focus-visible:outline-teal sm:p-5 ${
        a.status === 'new' ? 'border-red' : 'border-line'
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-lg font-semibold">
            {patientLabel(a)}
            {a.patient.name && <span className="ml-2 text-sm font-normal text-muted">{a.patient.shortId}</span>}
          </p>
          <p className="text-sm text-red">
            {VISIT_TYPE_LABEL[a.visit.type]} · {signs}
          </p>
        </div>
        <StatusPill status={a.status} />
      </div>
      <div className="mt-2 flex flex-wrap items-center justify-between gap-x-4 text-sm text-muted">
        <span>
          CHW {a.chw.name}
          {a.village && ` · ${a.village}`}
        </span>
        <time dateTime={a.createdAt} title={formatDateTime(a.createdAt)}>
          {timeAgo(a.createdAt)}
        </time>
      </div>
      <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
        <span className="flex flex-wrap gap-2">
          <ChannelBadge channel={a.channel} />
          {a.isPartial && <PendingTag />}
        </span>
        <span className="inline-flex items-center gap-1 text-sm font-semibold text-teal">
          Open case <ChevronIcon />
        </span>
      </div>
    </Link>
  );
}

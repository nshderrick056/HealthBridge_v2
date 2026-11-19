'use client';
import Link from 'next/link';
import { useState, type ReactNode } from 'react';
import { api, ApiError } from '@/lib/client';
import {
  describeAnswers,
  formatClock,
  formatDate,
  formatDateTime,
  POLL_MS,
  STATUS_LABEL,
  STATUS_ORDER,
  VISIT_TYPE_LABEL,
} from '@/lib/format';
import type { AlertDetail, AlertStatus } from '@/lib/types';
import { ChannelBadge, PendingTag, StatusPill } from './badges';
import { usePolling } from './usePolling';

type Action = Exclude<AlertStatus, 'new'>;

// Dark pills for the usual next steps, red only for escalating, white for the rest.
const ACTIONS: { status: Action; label: string; tone: 'dark' | 'red' | 'light' }[] = [
  { status: 'reviewed', label: 'Mark as reviewed', tone: 'dark' },
  { status: 'escalated', label: 'Escalate case', tone: 'red' },
  { status: 'follow_up', label: 'Request follow-up', tone: 'light' },
  { status: 'resolved', label: 'Mark resolved', tone: 'dark' },
];

const BUTTON = {
  dark: 'bg-ink text-white enabled:hover:bg-brand-deep',
  red: 'bg-red text-white enabled:hover:opacity-90',
  light: 'border-[1.5px] border-edge bg-white text-ink enabled:hover:bg-canvas',
};

const ERRORS: Record<string, string> = {
  status_changed: 'Someone else changed this case just now. The latest status is shown; check it and try again.',
  invalid_transition: 'This case can no longer move to that status. The latest status is shown.',
};

/** Today in Kigali as yyyy-mm-dd, the earliest follow-up date. */
const today = () => new Date(Date.now() + 2 * 3_600_000).toISOString().slice(0, 10);

export function CaseDetail({ id }: { id: string }) {
  const { data: c, error, reload } = usePolling<AlertDetail>(`alerts/${id}`, POLL_MS);
  // follow_up and resolved ask first: one needs a date, the other closes the case for good.
  const [confirming, setConfirming] = useState<Action | null>(null);
  const [note, setNote] = useState('');
  const [followUpBy, setFollowUpBy] = useState('');
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string>();

  if (!c) {
    return error === 'not_found' ? (
      <p className="rounded-3xl bg-white p-8 text-center text-muted shadow-card">
        This case does not exist or belongs to another health centre. <Link href="/alerts" className="font-semibold text-brand underline underline-offset-4">Back to alerts</Link>
      </p>
    ) : (
      <p className="text-muted" role={error ? 'alert' : undefined}>
        {error ? 'Could not load the case. Trying again in 10 seconds.' : 'Loading case…'}
      </p>
    );
  }

  async function act(status: Action) {
    if (status === 'follow_up' && !followUpBy) return setActionError('Choose a follow-up date.');
    const parts = [status === 'follow_up' ? `Follow up by ${formatDate(followUpBy)}` : '', note.trim()];
    setBusy(true);
    setActionError(undefined);
    try {
      await api(`alerts/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status, note: parts.filter(Boolean).join('. ') || undefined }),
      });
      setConfirming(null);
      setNote('');
      setFollowUpBy('');
    } catch (e) {
      setActionError(e instanceof ApiError ? (ERRORS[e.code] ?? 'Could not save. Try again.') : 'Could not save. Try again.');
    } finally {
      await reload();
      setBusy(false);
    }
  }

  const answers = describeAnswers(c.visit.answers);
  const village = c.patient.village;
  const open = c.status === 'new' || c.status === 'escalated';

  return (
    <div className="space-y-5">
      <Link
        href="/alerts"
        className="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-4 text-[15px] font-medium shadow-card hover:bg-teal-tint"
      >
        <span aria-hidden>←</span> All alerts
      </Link>
      <h1 className="sr-only">Urgent case detail</h1>

      <section
        className={`rounded-3xl p-6 text-white sm:p-8 ${open ? 'bg-red' : 'bg-gradient-to-br from-brand to-brand-light'}`}
      >
        <div className="flex flex-wrap items-start justify-between gap-3">
          <p className={`text-[15px] font-semibold ${open ? 'text-on-red' : 'text-on-brand'}`}>
            Urgent case · {c.patient.shortId}
          </p>
          <span className="rounded-full bg-white">
            <StatusPill status={c.status} />
          </span>
        </div>
        <p className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{c.patient.name ?? 'Name not received yet'}</p>
        <p className={`mt-2 text-[15px] ${open ? 'text-on-red' : 'text-on-brand'}`}>
          {[
            c.patient.sex === 'F' ? 'Female' : c.patient.sex === 'M' ? 'Male' : null,
            c.patient.ageEstimate != null ? `${c.patient.ageEstimate} years` : null,
            village || null,
            `${VISIT_TYPE_LABEL[c.visit.type]} warning signs`,
          ]
            .filter(Boolean)
            .join(' · ')}
        </p>
      </section>

      <div className="grid gap-5 lg:grid-cols-[3fr_2fr]">
        <div className="space-y-5">

          {c.visit.isPartial && (
            <div className="flex flex-wrap items-center gap-3 rounded-3xl bg-amber-tint p-5 text-[15px] text-warning">
              <PendingTag />
              Only the SMS alert has arrived. The full record appears here when the CHW&apos;s phone syncs.
            </div>
          )}

          <section className="rounded-3xl bg-white p-5 shadow-card sm:p-6" aria-labelledby="signs">
            <h2 id="signs" className="text-xl font-semibold tracking-tight">
              Key warning indicators
            </h2>
            {c.dangerSigns.length ? (
              <ul className="mt-3 space-y-2.5">
                {c.dangerSigns.map((s) => (
                  <li key={s.code} className="flex items-center gap-3 text-[17px] font-medium">
                    <span aria-hidden className="size-2.5 rounded-full bg-red" />
                    {s.label}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-2 text-sm text-muted">No danger signs recorded; the CHW flagged the visit as urgent.</p>
            )}
          </section>

          <Card>
            <h2 className="font-semibold">Reported issue</h2>
            {answers.length === 0 && !c.visit.notes && <p className="mt-1 text-sm text-muted">No details yet.</p>}
            {answers.length > 0 && (
              <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
                {answers.map(([k, v], i) => (
                  <div key={i} className="contents">
                    <dt className="text-muted">{k}</dt>
                    <dd>{v}</dd>
                  </div>
                ))}
              </dl>
            )}
            {c.visit.notes && <p className="mt-2 text-sm">{c.visit.notes}</p>}
            <dl className="mt-4 grid grid-cols-2 gap-4 border-t border-divider pt-4 text-sm sm:grid-cols-3">
              <Fact label="CHW">
                {c.chw.name}
                <a href={`tel:${c.chw.phone}`} className="block font-normal text-brand underline underline-offset-4">
                  {c.chw.phone}
                </a>
              </Fact>
              <Fact label="Village">{village || '—'}</Fact>
              <Fact label="Received">
                <time dateTime={c.createdAt} title={formatDateTime(c.createdAt)}>
                  {formatDateTime(c.createdAt)}
                </time>
              </Fact>
              <Fact label="Recorded on phone">{formatDateTime(c.visit.recordedAt)}</Fact>
              {c.visit.followUpOn && <Fact label="CHW follow-up date">{formatDate(c.visit.followUpOn)}</Fact>}
            </dl>
            <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-divider pt-4 text-sm">
              <div>
                <p className="text-muted">Alert method</p>
                <p>
                  {c.channel === 'sms' ? 'Delivered by SMS while the CHW was offline' : 'Sent over the internet'}
                  {c.ackedToChwAt && ` · confirmed to the CHW at ${formatClock(c.ackedToChwAt)}`}
                </p>
              </div>
              <ChannelBadge channel={c.channel} />
            </div>
          </Card>
        </div>

        <div className="space-y-4">
          <Card>
            <h2 className="text-xl font-semibold tracking-tight">Case status</h2>
            <ol className="mt-3 flex flex-wrap gap-2">
              {STATUS_ORDER.map((s) => (
                <li key={s} aria-current={s === c.status ? 'step' : undefined}>
                  {s === c.status ? (
                    <StatusPill status={s} />
                  ) : (
                    <span className="inline-flex rounded-full bg-canvas px-3 py-1 text-sm text-muted">{STATUS_LABEL[s]}</span>
                  )}
                </li>
              ))}
            </ol>
          </Card>

          <Card>
            <h2 className="font-semibold">Take action</h2>
            {c.next.length === 0 ? (
              <p className="mt-2 text-sm text-muted">This case is resolved and closed.</p>
            ) : (
              <>
                <label className="mt-3 block text-sm">
                  <span className="text-muted">Note for the case history (optional)</span>
                  <textarea
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    maxLength={400}
                    rows={2}
                    className="mt-2 block w-full rounded-2xl border-[1.5px] border-edge bg-white px-4 py-3 focus:border-brand focus:outline-none"
                  />
                </label>
                <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
                  {ACTIONS.map(({ status, label, tone }) => (
                    <button
                      key={status}
                      type="button"
                      disabled={busy || !c.next.includes(status)}
                      onClick={() => (status === 'follow_up' || status === 'resolved' ? setConfirming(status) : act(status))}
                      className={`min-h-12 rounded-full px-4 text-[15px] font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-35 ${BUTTON[tone]}`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
                {confirming && (
                  <div className="mt-4 space-y-3 rounded-2xl bg-canvas p-4 text-[15px]">
                    {confirming === 'follow_up' ? (
                      <label className="block">
                        <span className="text-muted">Follow up by</span>
                        <input
                          type="date"
                          min={today()}
                          value={followUpBy}
                          onChange={(e) => setFollowUpBy(e.target.value)}
                          className="mt-2 block min-h-11 rounded-2xl border-[1.5px] border-edge bg-white px-4"
                        />
                      </label>
                    ) : (
                      <p>Close this case? A resolved case cannot be reopened.</p>
                    )}
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => act(confirming)}
                        className="min-h-11 rounded-full bg-ink px-5 font-semibold text-white disabled:opacity-40"
                      >
                        {confirming === 'follow_up' ? 'Send follow-up request' : 'Resolve case'}
                      </button>
                      <button
                        type="button"
                        onClick={() => setConfirming(null)}
                        className="min-h-11 rounded-full px-4 font-semibold text-ink underline underline-offset-4"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
            {busy && (
              <p role="status" className="mt-3 text-sm text-muted">
                Saving…
              </p>
            )}
            {actionError && (
              <p role="alert" className="mt-3 text-sm text-red">
                {actionError}
              </p>
            )}
          </Card>

          <Card>
            <h2 className="font-semibold">History</h2>
            <ol className="mt-2 space-y-3 text-sm">
              <li>
                <p>Alert received {c.channel === 'sms' ? 'by SMS' : 'over the internet'}</p>
                <p className="text-muted">{formatDateTime(c.createdAt)}</p>
              </li>
              {c.events.map((e) => (
                <li key={e.id}>
                  <p>
                    {STATUS_LABEL[e.toStatus]}
                    {e.actor && <span className="text-muted"> by {e.actor}</span>}
                  </p>
                  {e.note && <p>{e.note}</p>}
                  <p className="text-muted">{formatDateTime(e.createdAt)}</p>
                </li>
              ))}
            </ol>
          </Card>
        </div>
      </div>
    </div>
  );
}

function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <section className={`rounded-3xl bg-white p-5 shadow-card sm:p-6 ${className}`}>{children}</section>;
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-muted">{label}</dt>
      <dd className="font-semibold">{children}</dd>
    </div>
  );
}

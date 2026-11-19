'use client';
import { useState } from 'react';
import { errorText, type ResetRequest } from '@/lib/admin';
import { api, ApiError } from '@/lib/client';
import { formatDateTime, timeAgo } from '@/lib/format';
import { Avatar } from '../badges';
import { usePolling } from '../usePolling';

const ROLE: Record<string, string> = { chw: 'CHW', supervisor: 'Supervisor', admin: 'Admin' };

/** People who asked to reset their PIN or password. Approving texts them a one-time code. */
export function ResetRequests() {
  const { data, error, reload } = usePolling<{ requests: ResetRequest[] }>('admin/reset-requests', 30_000);
  const [busy, setBusy] = useState<string>();
  const [result, setResult] = useState<{ ok: boolean; text: string }>();

  async function approve(r: ResetRequest) {
    setBusy(r.id);
    setResult(undefined);
    try {
      await api(`admin/reset-requests/${r.id}/approve`, { method: 'POST' });
      setResult({ ok: true, text: `Approved. ${r.name ?? 'They'} will get a code by SMS, valid for 30 minutes.` });
    } catch (e) {
      setResult({ ok: false, text: errorText(e instanceof ApiError ? e.code : 'request_failed') });
    } finally {
      await reload();
      setBusy(undefined);
    }
  }

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Reset requests</h1>
        <p className="mt-1 max-w-3xl text-muted">
          When you approve, the person gets a new sign-in code by SMS. Check it is really them first, by phone or in
          person.
        </p>
      </header>

      {result && (
        <p
          role={result.ok ? 'status' : 'alert'}
          className={`rounded-2xl px-4 py-3 text-[15px] ${result.ok ? 'bg-teal-tint text-brand' : 'bg-red-tint text-red'}`}
        >
          {result.text}
        </p>
      )}
      {error && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load the requests. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && data.requests.length === 0 && (
        <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">No one is waiting.</p>
      )}
      {data && data.requests.length > 0 && (
        <ul className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
          {data.requests.map((r) => (
            <li key={r.id} className="flex flex-wrap items-center gap-4 px-5 py-4 sm:px-6">
              <Avatar name={r.name ?? '?'} />
              <div className="min-w-0 flex-1">
                <p className="text-[17px] font-semibold">
                  {r.name ?? 'Unknown account'}
                  {r.role && (
                    <span className="ml-2 rounded-full bg-canvas px-2.5 py-0.5 text-sm font-medium text-muted">
                      {ROLE[r.role] ?? r.role}
                    </span>
                  )}
                </p>
                <p className="text-[15px] text-muted">
                  {r.phone ?? 'No phone'}
                  {r.createdAt && (
                    <>
                      {' · asked '}
                      <time dateTime={r.createdAt} title={formatDateTime(r.createdAt)}>
                        {timeAgo(r.createdAt)}
                      </time>
                    </>
                  )}
                </p>
              </div>
              <button
                type="button"
                disabled={busy !== undefined}
                onClick={() => approve(r)}
                className="min-h-11 rounded-full bg-ink px-5 text-[15px] font-semibold text-white hover:bg-brand-deep disabled:opacity-40"
              >
                {busy === r.id ? 'Approving…' : 'Approve'}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

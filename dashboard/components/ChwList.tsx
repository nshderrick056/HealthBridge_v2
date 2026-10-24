'use client';
import { formatDateTime, timeAgo } from '@/lib/format';
import type { Chw } from '@/lib/types';
import { usePolling } from './usePolling';

const STALE_MS = 24 * 3_600_000;
const ROLE: Record<string, string> = { asm: 'ASM', binome: 'Binôme' };

export function ChwList() {
  const { data, error } = usePolling<{ chws: Chw[] }>('chws', 30_000);
  const now = Date.now();

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold sm:text-3xl">Community health workers</h1>
        <p className="text-sm text-muted">
          Last sync is the latest time any of a CHW&apos;s phones reached the server. Pending counts urgent cases that
          arrived only by SMS and still wait for the phone&apos;s full record.
        </p>
      </header>

      {error && (
        <p role="alert" className="rounded-xl bg-red-tint px-4 py-3 text-sm text-red">
          Could not load the CHW list. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && data.chws.length === 0 && (
        <p className="rounded-2xl border border-line bg-white px-5 py-10 text-center text-muted">
          No CHWs are registered at this health centre.
        </p>
      )}
      {data && data.chws.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-line bg-white">
          <table className="w-full min-w-[36rem] text-left text-sm">
            <thead className="border-b border-divider text-muted">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Last sync</th>
                <th className="px-4 py-3 text-right font-semibold">Pending</th>
              </tr>
            </thead>
            <tbody>
              {data.chws.map((c) => {
                const stale = !c.lastSyncAt || now - new Date(c.lastSyncAt).getTime() > STALE_MS;
                return (
                  <tr key={c.id} className="border-b border-divider last:border-0">
                    <td className="px-4 py-3">
                      <span className="font-semibold">{c.name}</span>
                      {c.chwRole && <span className="ml-2 text-xs text-muted">{ROLE[c.chwRole]}</span>}
                    </td>
                    <td className="px-4 py-3">{c.village ?? '—'}</td>
                    <td className="px-4 py-3">
                      <a href={`tel:${c.phone}`} className="text-teal">
                        {c.phone}
                      </a>
                    </td>
                    <td className={`px-4 py-3 ${stale ? 'font-semibold text-warning' : ''}`}>
                      {c.lastSyncAt ? (
                        <time dateTime={c.lastSyncAt} title={formatDateTime(c.lastSyncAt)}>
                          {timeAgo(c.lastSyncAt, now)}
                        </time>
                      ) : (
                        'Never'
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {c.pendingCount > 0 ? (
                        <span className="rounded-full bg-amber-tint px-2.5 py-0.5 font-semibold text-warning">{c.pendingCount}</span>
                      ) : (
                        <span className="text-muted">0</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

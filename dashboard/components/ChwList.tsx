'use client';
import Link from 'next/link';
import { formatDateTime, timeAgo } from '@/lib/format';
import type { Chw } from '@/lib/types';
import { Avatar } from './badges';
import { usePolling } from './usePolling';

const STALE_MS = 24 * 3_600_000;
const ROLE: Record<string, string> = { asm: 'ASM', binome: 'Binôme' };

export function ChwList() {
  const { data, error } = usePolling<{ chws: Chw[] }>('chws', 30_000);
  const now = Date.now();

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Community health workers</h1>
        <p className="mt-1 max-w-3xl text-muted">
          Last sync is the latest time any of a CHW&apos;s phones reached the server. Pending counts urgent cases that
          arrived only by SMS and still wait for the phone&apos;s full record.
        </p>
      </header>

      {error && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load the CHW list. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && data.chws.length === 0 && (
        <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">
          No CHWs are registered at this health centre.
        </p>
      )}
      {data && data.chws.length > 0 && (
        <div className="overflow-x-auto rounded-3xl bg-white px-2 py-2 shadow-card">
          <table className="w-full min-w-[36rem] text-left text-[15px]">
            <thead className="border-b border-divider text-sm text-muted">
              <tr>
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Village</th>
                <th className="px-4 py-3 font-medium">Phone</th>
                <th className="px-4 py-3 font-medium">Last sync</th>
                <th className="px-4 py-3 text-right font-medium">Pending</th>
              </tr>
            </thead>
            <tbody>
              {data.chws.map((c) => {
                const stale = !c.lastSyncAt || now - new Date(c.lastSyncAt).getTime() > STALE_MS;
                return (
                  <tr key={c.id} className="border-b border-divider last:border-0">
                    <td className="px-4 py-3">
                      <span className="flex items-center gap-3">
                        <Avatar name={c.name} tone={c.pendingCount > 0 ? 'due' : 'plain'} />
                        <span>
                          <Link href={`/chws/${c.id}`} className="font-semibold underline-offset-4 hover:underline">
                            {c.name}
                          </Link>
                          {c.chwRole && <span className="ml-2 text-sm text-muted">{ROLE[c.chwRole]}</span>}
                        </span>
                      </span>
                    </td>
                    <td className="px-4 py-3">{c.village ?? '—'}</td>
                    <td className="px-4 py-3">
                      <a href={`tel:${c.phone}`} className="text-brand underline underline-offset-4">
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

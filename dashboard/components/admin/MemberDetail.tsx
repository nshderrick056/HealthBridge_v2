'use client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, type ReactNode } from 'react';
import { errorText, type Member } from '@/lib/admin';
import { api, ApiError } from '@/lib/client';
import { formatDateTime } from '@/lib/format';
import { Avatar } from '../badges';
import { usePolling } from '../usePolling';

const ROLE = { chw: 'CHW', supervisor: 'Supervisor' };
const CHW_ROLE = { asm: 'ASM (maternal and newborn)', binome: 'Binôme' };

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-wrap justify-between gap-x-6 gap-y-1 px-5 py-3.5 sm:px-6">
      <dt className="text-muted">{label}</dt>
      <dd className="font-medium">{children}</dd>
    </div>
  );
}

/** One member's details, with Deactivate / Activate and Delete (which asks first). */
export function MemberDetail({ id }: { id: string }) {
  const router = useRouter();
  const { data, error, reload } = usePolling<Member>(`admin/users/${id}`, 60_000);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState<string>();

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setFailed(undefined);
    try {
      await fn();
    } catch (e) {
      setFailed(errorText(e instanceof ApiError ? e.code : 'request_failed'));
    } finally {
      setBusy(false);
    }
  }

  const setActive = (active: boolean) =>
    run(async () => {
      await api(`admin/users/${id}`, { method: 'PATCH', body: JSON.stringify({ active }) });
      await reload();
    });

  const remove = () =>
    run(async () => {
      await api(`admin/users/${id}`, { method: 'DELETE' });
      router.replace('/admin/members');
    });

  return (
    <div className="space-y-6">
      <Link
        href="/admin/members"
        className="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-4 text-[15px] font-medium shadow-card hover:bg-teal-tint"
      >
        <span aria-hidden>←</span> All members
      </Link>
      {error === 'not_found' && (
        <p className="rounded-3xl bg-white p-8 text-center text-muted shadow-card">This member no longer exists.</p>
      )}
      {error && error !== 'not_found' && !data && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          Could not load this member. Trying again shortly.
        </p>
      )}
      {!data && !error && <p className="text-muted">Loading…</p>}
      {data && (
        <>
          <header className="flex items-center gap-4">
            <Avatar name={data.fullName} tone={data.active ? 'lime' : 'due'} />
            <div>
              <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">{data.fullName}</h1>
              <p className="mt-1 text-muted">
                {ROLE[data.role]}
                {' · '}
                <span className={data.active ? 'text-brand' : 'font-semibold text-warning'}>
                  {data.active ? 'Active' : 'Switched off'}
                </span>
              </p>
            </div>
          </header>

          <dl className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
            <Row label="Phone">
              <a href={`tel:${data.phone}`} className="text-brand underline underline-offset-4">
                {data.phone}
              </a>
            </Row>
            <Row label="Email">{data.email ?? '—'}</Row>
            {data.role === 'chw' && <Row label="CHW role">{data.chwRole ? CHW_ROLE[data.chwRole] : '—'}</Row>}
            {data.role === 'chw' && <Row label="Village">{data.village ?? '—'}</Row>}
            <Row label="Health centre">
              {data.healthCenterId ? (
                <Link href={`/admin/centres/${data.healthCenterId}`} className="text-brand underline underline-offset-4">
                  {data.healthCenterName ?? 'Open'}
                </Link>
              ) : (
                '—'
              )}
            </Row>
            <Row label="Added">{data.createdAt ? formatDateTime(data.createdAt) : '—'}</Row>
          </dl>

          {failed && (
            <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
              {failed}
            </p>
          )}

          <section className="space-y-3 rounded-3xl bg-white p-5 shadow-card sm:p-6">
            <h2 className="text-xl font-semibold tracking-tight">Account</h2>
            <p className="text-[15px] text-muted">
              Deactivating stops every way of signing in, at once, and keeps their records. You can activate it again.
            </p>
            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                disabled={busy}
                onClick={() => setActive(!data.active)}
                className="min-h-12 rounded-full border-[1.5px] border-edge bg-white px-6 font-semibold hover:bg-canvas disabled:opacity-40"
              >
                {data.active ? 'Deactivate' : 'Activate'}
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => setConfirming(true)}
                className="min-h-12 rounded-full bg-red px-6 font-semibold text-white hover:opacity-90 disabled:opacity-40"
              >
                Delete
              </button>
            </div>
            {confirming && (
              <div role="alertdialog" aria-label="Confirm delete" className="space-y-3 rounded-2xl bg-red-tint p-4 text-[15px]">
                <p>
                  Delete <strong>{data.fullName}</strong>? Their account and sign-in details are removed for good and
                  this cannot be undone. The patients and visits they recorded are kept. To only stop them signing in,
                  use Deactivate.
                </p>
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={remove}
                    className="min-h-11 rounded-full bg-red px-5 font-semibold text-white disabled:opacity-40"
                  >
                    Yes, delete
                  </button>
                  <button
                    type="button"
                    onClick={() => setConfirming(false)}
                    className="min-h-11 rounded-full px-4 font-semibold underline underline-offset-4"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </section>
        </>
      )}
    </div>
  );
}

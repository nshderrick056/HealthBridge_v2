'use client';
import { useState, type FormEvent } from 'react';
import { errorText, normalizePhone, type Centre } from '@/lib/admin';
import { api, ApiError } from '@/lib/client';
import { HospitalIcon } from '../icons';
import { usePolling } from '../usePolling';

const input =
  'mt-2 block w-full min-h-12 rounded-2xl border-[1.5px] border-edge bg-white px-4 text-base focus:border-brand focus:outline-none';

/** Health centres, and a form to add one. Every account belongs to one; alerts give CHWs its call number. */
export function Centres() {
  const { data, error, reload } = usePolling<{ centres: Centre[] }>('admin/health-centers', 60_000);
  const [name, setName] = useState('');
  const [district, setDistrict] = useState('');
  const [sector, setSector] = useState('');
  const [call, setCall] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string }>();

  async function submit(e: FormEvent) {
    e.preventDefault();
    setResult(undefined);
    if (name.trim().length < 2) return setResult({ ok: false, text: 'Enter the name (2 letters or more).' });
    if (!district.trim() || !sector.trim()) return setResult({ ok: false, text: 'Enter the district and sector.' });
    const callNumber = call.trim() ? normalizePhone(call) : undefined;
    if (callNumber === null) return setResult({ ok: false, text: 'Enter the call number like 0788 000 111, or leave it empty.' });
    setBusy(true);
    try {
      await api('admin/health-centers', {
        method: 'POST',
        body: JSON.stringify({
          name: name.trim(),
          district: district.trim(),
          sector: sector.trim(),
          ...(callNumber && { callNumber }),
        }),
      });
      setResult({ ok: true, text: `${name.trim()} added.` });
      setName('');
      setDistrict('');
      setSector('');
      setCall('');
      await reload();
    } catch (err) {
      setResult({ ok: false, text: errorText(err instanceof ApiError ? err.code : 'request_failed') });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Health centres</h1>
        <p className="mt-1 max-w-3xl text-muted">
          CHWs and supervisors belong to one health centre. Urgent alerts tell CHWs to call its number.
        </p>
      </header>

      <div className="grid gap-5 lg:grid-cols-[1fr_22rem]">
        <section aria-label="Health centres">
          {error && !data && (
            <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
              Could not load the health centres. Trying again shortly.
            </p>
          )}
          {!data && !error && <p className="text-muted">Loading…</p>}
          {data && data.centres.length === 0 && (
            <p className="rounded-3xl bg-white px-6 py-10 text-center text-muted shadow-card">No health centres yet.</p>
          )}
          {data && data.centres.length > 0 && (
            <ul className="divide-y divide-line overflow-hidden rounded-3xl bg-white shadow-card">
              {data.centres.map((c) => (
                <li key={c.id} className="flex items-center gap-4 px-5 py-4 sm:px-6">
                  <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-teal-tint text-brand">
                    <HospitalIcon className="size-5" />
                  </span>
                  <div className="min-w-0">
                    <p className="text-[17px] font-semibold">{c.name}</p>
                    {c.district && <p className="text-[15px] text-muted">{c.district}</p>}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>

        <form onSubmit={submit} noValidate className="h-fit space-y-4 rounded-3xl bg-white p-6 shadow-card">
          <h2 className="text-xl font-semibold tracking-tight">Add a health centre</h2>
          <label className="block text-[15px] font-medium">
            Name
            <input className={input} value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Mayange Health Centre" />
          </label>
          <label className="block text-[15px] font-medium">
            District
            <input className={input} value={district} onChange={(e) => setDistrict(e.target.value)} />
          </label>
          <label className="block text-[15px] font-medium">
            Sector
            <input className={input} value={sector} onChange={(e) => setSector(e.target.value)} />
          </label>
          <label className="block text-[15px] font-medium">
            Call number (optional)
            <input className={input} type="tel" value={call} onChange={(e) => setCall(e.target.value)} placeholder="0788 000 111" />
          </label>
          {result && (
            <p
              role={result.ok ? 'status' : 'alert'}
              className={`rounded-2xl px-4 py-3 text-[15px] ${result.ok ? 'bg-teal-tint text-brand' : 'bg-red-tint text-red'}`}
            >
              {result.text}
            </p>
          )}
          <button
            type="submit"
            disabled={busy}
            className="min-h-13 w-full rounded-full bg-ink font-semibold text-white hover:bg-brand-deep disabled:opacity-40"
          >
            {busy ? 'Adding…' : 'Add health centre'}
          </button>
        </form>
      </div>
    </div>
  );
}

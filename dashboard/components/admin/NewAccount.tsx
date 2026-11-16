'use client';
import { useState, type FormEvent, type ReactNode } from 'react';
import { errorText, normalizePhone, type Centre } from '@/lib/admin';
import { api, ApiError } from '@/lib/client';
import { usePolling } from '../usePolling';

type Role = 'chw' | 'supervisor';

const input =
  'mt-2 block w-full min-h-12 rounded-2xl border-[1.5px] border-edge bg-white px-4 text-base focus:border-brand focus:outline-none';

function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block text-[15px] font-medium">
      {label}
      {children}
      {hint && <span className="mt-1 block text-sm font-normal text-muted">{hint}</span>}
    </label>
  );
}

/**
 * Creates a CHW (phone, optional email) or a supervisor (phone + email). The server makes a temporary
 * PIN and/or password and texts it; the admin never sees it, and the person sets their own at first sign-in.
 */
export function NewAccount() {
  const { data } = usePolling<{ centres: Centre[] }>('admin/health-centers', 60_000);
  const [role, setRole] = useState<Role>('chw');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [centre, setCentre] = useState('');
  const [chwRole, setChwRole] = useState<'asm' | 'binome'>('asm');
  const [village, setVillage] = useState('');
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string }>();

  const intl = normalizePhone(phone);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setResult(undefined);
    if (fullName.trim().length < 2) return setResult({ ok: false, text: 'Enter the full name (2 letters or more).' });
    if (!intl) return setResult({ ok: false, text: 'Enter a phone number, e.g. 0788 123 456.' });
    if (!centre) return setResult({ ok: false, text: 'Choose a health centre.' });
    if (role === 'chw' && !village.trim()) return setResult({ ok: false, text: 'Enter the village.' });
    if (role === 'supervisor' && !email.trim()) return setResult({ ok: false, text: 'A supervisor needs an email.' });
    setBusy(true);
    try {
      const out = await api<{ smsSent: boolean }>('admin/users', {
        method: 'POST',
        body: JSON.stringify({
          role,
          fullName: fullName.trim(),
          phone: intl,
          healthCenterId: centre,
          ...(role === 'chw' && { chwRole, village: village.trim() }),
          ...(email.trim() && { email: email.trim() }),
        }),
      });
      setResult(
        out.smsSent
          ? { ok: true, text: `Account created for ${fullName.trim()}. Their sign-in details were sent by SMS.` }
          : {
              ok: false,
              text: `Account created for ${fullName.trim()}, but the SMS failed. They can get in with Forgot PIN or password.`,
            },
      );
      setFullName('');
      setPhone('');
      setVillage('');
      setEmail('');
    } catch (err) {
      setResult({ ok: false, text: errorText(err instanceof ApiError ? err.code : 'request_failed') });
    } finally {
      setBusy(false);
    }
  }

  const preview = [
    role === 'chw' && 'PIN ••••••',
    (role === 'supervisor' || email.trim()) && `email ${email.trim() || '…'} and password ••••••••`,
  ]
    .filter(Boolean)
    .join(', or ');

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Add an account</h1>
        <p className="mt-1 max-w-3xl text-muted">
          There is no self sign-up. The person gets a temporary PIN or password by SMS and chooses their own at first
          sign-in.
        </p>
      </header>

      <div className="grid gap-5 lg:grid-cols-[1fr_22rem]">
        <form onSubmit={submit} noValidate className="space-y-5 rounded-3xl bg-white p-6 shadow-card sm:p-7">
          <fieldset>
            <legend className="text-[15px] font-medium">Role</legend>
            <div className="mt-2 flex gap-2">
              {(['chw', 'supervisor'] as const).map((r) => (
                <button
                  key={r}
                  type="button"
                  aria-pressed={role === r}
                  onClick={() => setRole(r)}
                  className={`min-h-11 rounded-full px-5 text-[15px] ${
                    role === r ? 'bg-ink font-semibold text-white' : 'bg-canvas text-ink hover:bg-teal-tint'
                  }`}
                >
                  {r === 'chw' ? 'CHW' : 'Supervisor'}
                </button>
              ))}
            </div>
          </fieldset>

          <div className="grid gap-5 sm:grid-cols-2">
            <Field label="Full name">
              <input className={input} value={fullName} onChange={(e) => setFullName(e.target.value)} autoComplete="off" />
            </Field>
            <Field label="Phone" hint="The SMS goes to this number.">
              <input
                className={input}
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="0788 123 456"
              />
            </Field>
            <Field label="Health centre">
              <select className={input} value={centre} onChange={(e) => setCentre(e.target.value)}>
                <option value="">Choose…</option>
                {data?.centres.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </Field>
            {role === 'chw' ? (
              <Field label="CHW role">
                <select
                  className={input}
                  value={chwRole}
                  onChange={(e) => setChwRole(e.target.value as 'asm' | 'binome')}
                >
                  <option value="asm">ASM (maternal and newborn)</option>
                  <option value="binome">Binôme</option>
                </select>
              </Field>
            ) : (
              <Field label="Email">
                <input className={input} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
              </Field>
            )}
            {role === 'chw' && (
              <>
                <Field label="Village">
                  <input className={input} value={village} onChange={(e) => setVillage(e.target.value)} />
                </Field>
                <Field label="Email (optional)" hint="Add one so they can also sign in with a password.">
                  <input className={input} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
                </Field>
              </>
            )}
          </div>

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
            className="min-h-13 rounded-full bg-ink px-6 font-semibold text-white hover:bg-brand-deep disabled:opacity-40"
          >
            {busy ? 'Creating…' : 'Create account and send SMS'}
          </button>
        </form>

        <aside className="h-fit space-y-3 rounded-3xl bg-gradient-to-br from-brand to-brand-deep p-6 text-white sm:p-7">
          <h2 className="text-xl font-semibold tracking-tight">What they receive</h2>
          <p className="text-[15px] text-on-brand">Text message to {intl ?? 'their phone'}</p>
          <p className="rounded-3xl rounded-bl-md bg-white p-4 text-[15px] leading-relaxed text-ink">
            HealthBridge: your account is ready. Sign in with {preview}. You will then choose your own.
          </p>
          <p className="text-[15px] text-on-brand">
            The server makes the PIN or password; you never see it. If the SMS fails, they can use Forgot PIN.
          </p>
        </aside>
      </div>
    </div>
  );
}

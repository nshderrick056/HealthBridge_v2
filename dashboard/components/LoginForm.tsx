'use client';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

const MESSAGES: Record<string, string> = {
  invalid_credentials: 'Wrong email or password.',
  invalid_request: 'Enter your email and a password of at least 8 characters.',
  too_many_attempts: 'Too many attempts. Wait 15 minutes, then try again.',
  not_supervisor: 'This account cannot use the dashboard. CHWs use the HealthBridge app.',
  must_change: 'You are using the temporary password from the SMS. Sign in to the HealthBridge app first to choose your own.',
  api_unreachable: 'Cannot reach the HealthBridge server. Check your connection and try again.',
};

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(undefined);
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: email.trim(), password }),
      });
      if (res.ok) {
        const { role } = (await res.json().catch(() => ({}))) as { role?: string };
        router.replace(role === 'admin' ? '/admin/resets' : '/alerts');
        router.refresh();
        return;
      }
      const { error: code } = (await res.json().catch(() => ({}))) as { error?: string };
      setError(MESSAGES[code ?? ''] ?? 'Could not sign in. Try again.');
    } catch {
      setError(MESSAGES.api_unreachable);
    }
    setBusy(false);
  }

  const field =
    'mt-2 block w-full rounded-2xl border-[1.5px] border-edge bg-white px-4 py-3.5 text-base focus:border-brand focus:outline-none';
  return (
    <form onSubmit={submit} className="space-y-5">
      <label className="block text-[15px] font-medium">
        Email
        <input
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className={field}
        />
      </label>
      <label className="block text-[15px] font-medium">
        Password
        <input
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className={field}
        />
      </label>
      {error && (
        <p role="alert" className="rounded-2xl bg-red-tint px-4 py-3 text-[15px] text-red">
          {error}
        </p>
      )}
      <button
        type="submit"
        disabled={busy}
        className="min-h-14 w-full rounded-full bg-ink font-semibold text-white hover:bg-brand-deep disabled:opacity-50"
      >
        {busy ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  );
}

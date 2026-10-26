'use client';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

const MESSAGES: Record<string, string> = {
  invalid_credentials: 'Wrong email or password.',
  invalid_request: 'Enter your email and a password of at least 8 characters.',
  too_many_attempts: 'Too many attempts. Wait 15 minutes, then try again.',
  not_supervisor: 'This account cannot use the supervisor dashboard.',
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
        router.replace('/alerts');
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
    'mt-1 block w-full rounded-xl border border-line bg-white px-3 py-2.5 text-base focus:border-teal focus:outline-none';
  return (
    <form onSubmit={submit} className="space-y-4">
      <label className="block text-sm font-semibold">
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
      <label className="block text-sm font-semibold">
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
        <p role="alert" className="rounded-xl bg-red-tint px-3 py-2 text-sm text-red">
          {error}
        </p>
      )}
      <button
        type="submit"
        disabled={busy}
        className="w-full rounded-2xl bg-teal py-3 font-semibold text-white hover:bg-teal-dark disabled:opacity-50"
      >
        {busy ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  );
}

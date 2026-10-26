import type { Metadata } from 'next';
import { LoginForm } from '@/components/LoginForm';

export const metadata: Metadata = { title: 'Sign in' };

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-sm">
        <p className="text-sm font-semibold tracking-wide text-teal">HealthBridge Rwanda</p>
        <h1 className="mt-1 text-2xl font-bold">Supervisor dashboard</h1>
        <p className="mt-1 mb-6 text-sm text-muted">Sign in with your health centre email.</p>
        <div className="rounded-2xl border border-line bg-white p-5">
          <LoginForm />
        </div>
      </div>
    </main>
  );
}

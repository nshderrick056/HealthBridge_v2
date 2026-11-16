import type { Metadata } from 'next';
import { LoginForm } from '@/components/LoginForm';

export const metadata: Metadata = { title: 'Sign in' };

/** Green brand panel beside the form on wide screens (Figma "Supervisor sign in"); form alone on phones. */
export default function LoginPage() {
  return (
    <main className="flex min-h-screen">
      <section
        aria-hidden
        className="hidden w-1/2 flex-col justify-between bg-gradient-to-br from-brand to-brand-deep p-16 lg:flex"
      >
        <p className="text-2xl font-semibold tracking-tight text-lime">HealthBridge</p>
        <div>
          <p className="text-5xl leading-[1.08] font-semibold tracking-tight text-white">
            Urgent visits from the field, the moment they are sent.
          </p>
          <p className="mt-5 max-w-md text-lg text-on-brand">
            CHW alerts arrive here by internet or by SMS, even when the phone was offline.
          </p>
        </div>
      </section>
      <div className="flex flex-1 items-center justify-center px-4 py-10">
        <div className="w-full max-w-sm">
          <p className="text-lg font-semibold text-brand lg:hidden">HealthBridge</p>
          <h1 className="mt-1 text-4xl font-semibold tracking-tight">Sign in</h1>
          <p className="mt-2 mb-6 text-muted">
            For supervisors. Use the email and password your admin set up.
          </p>
          <LoginForm />
          <p className="mt-5 text-[15px] text-muted">
            First time? Sign in to the HealthBridge app first to choose your own password.
          </p>
        </div>
      </div>
    </main>
  );
}

import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { LoginForm } from '@/components/LoginForm';
import { json, mockFetch } from './helpers';

const router = vi.hoisted(() => ({ replace: vi.fn(), refresh: vi.fn() }));
vi.mock('next/navigation', () => ({ useRouter: () => router }));

async function signIn(password = 'long-enough') {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('Email'), 'supervisor@example.test');
  await user.type(screen.getByLabelText('Password'), password);
  await user.click(screen.getByRole('button', { name: 'Sign in' }));
}

describe('LoginForm', () => {
  beforeEach(() => {
    router.replace.mockClear();
  });

  it('posts the credentials to the login route and opens the inbox', async () => {
    const fetch = mockFetch(() => json({ name: 'Demo Supervisor' }));
    render(<LoginForm />);
    await signIn();

    expect(fetch.mock.calls[0][0]).toBe('/api/auth/login');
    expect(JSON.parse(String(fetch.mock.calls[0][1]?.body))).toEqual({
      email: 'supervisor@example.test',
      password: 'long-enough',
    });
    expect(router.replace).toHaveBeenCalledWith('/alerts');
  });

  it.each([
    ['invalid_credentials', 401, 'Wrong email or password.'],
    ['too_many_attempts', 429, 'Too many attempts'],
    ['not_supervisor', 403, 'cannot use the supervisor dashboard'],
  ])('explains %s', async (error, status, message) => {
    mockFetch(() => json({ error }, status));
    render(<LoginForm />);
    await signIn();

    expect(await screen.findByRole('alert')).toHaveTextContent(message);
    expect(router.replace).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Sign in' })).toBeEnabled();
  });
});

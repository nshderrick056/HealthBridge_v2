import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { MemberDetail } from '@/components/admin/MemberDetail';
import { json, mockFetch } from './helpers';

const router = vi.hoisted(() => ({ replace: vi.fn() }));
vi.mock('next/navigation', () => ({ useRouter: () => router }));

const member = { id: 'u1', role: 'chw', fullName: 'Mukamana Alice', phone: '+250780000310', email: null, chwRole: 'binome', village: 'Gatare', healthCenterId: 'hc1', healthCenterName: 'Gatare HC', active: true, createdAt: '2026-11-01T08:00:00Z' };

describe('MemberDetail', () => {
  it('shows the details, deactivates, and deletes only after confirming', async () => {
    let active = true;
    const fetch = mockFetch((url, init) => {
      if (init?.method === 'PATCH') { active = JSON.parse(String(init.body)).active; return json({ id: 'u1', active }); }
      if (init?.method === 'DELETE') return json({ id: 'u1', deleted: true });
      return json({ ...member, active });
    });
    const user = userEvent.setup();
    render(<MemberDetail id="u1" />);

    expect(await screen.findByRole('heading', { name: 'Mukamana Alice' })).toBeInTheDocument();
    expect(screen.getByText('Gatare')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Gatare HC' })).toHaveAttribute('href', '/admin/centres/hc1');

    await user.click(screen.getByRole('button', { name: 'Deactivate' }));
    expect(await screen.findByRole('button', { name: 'Activate' })).toBeInTheDocument();
    expect(fetch.mock.calls.some(([, i]) => i?.method === 'PATCH')).toBe(true);

    await user.click(screen.getByRole('button', { name: 'Delete' }));
    expect(fetch.mock.calls.some(([, i]) => i?.method === 'DELETE')).toBe(false); // asks first
    await user.click(screen.getByRole('button', { name: 'Yes, delete' }));
    expect(router.replace).toHaveBeenCalledWith('/admin/members');
  });
});

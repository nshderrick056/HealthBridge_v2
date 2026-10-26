import { act, render, screen, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { AlertInbox } from '@/components/AlertInbox';
import type { AlertList } from '@/lib/types';
import { internetAlert, json, mockFetch, smsAlert } from './helpers';

const list: AlertList = {
  alerts: [smsAlert, internetAlert],
  counts: { new: 1, reviewed: 1, escalated: 0, follow_up: 2, resolved: 3 },
};

describe('AlertInbox', () => {
  it('lists alerts newest first with channel badge, CHW, village and the pending tag', async () => {
    const fetch = mockFetch(() => json(list));
    render(<AlertInbox filter="open" />);

    const items = await screen.findAllByRole('listitem');
    expect(fetch.mock.calls[0][0]).toBe('/api/alerts?status=open');

    // SMS-only case: no name yet, so the short ID stands in, and the full record is pending.
    expect(within(items[0]).getByText('Patient P0412')).toBeInTheDocument();
    expect(within(items[0]).getByText('SMS fallback')).toBeInTheDocument();
    expect(within(items[0]).getByText('Full record pending')).toBeInTheDocument();
    expect(within(items[0]).getByText('Maternal · Heavy bleeding · Convulsions')).toBeInTheDocument();
    expect(within(items[0]).getByText(/CHW Claudine M\. · Nyamata/)).toBeInTheDocument();
    expect(within(items[0]).getByText('6 min ago')).toBeInTheDocument();
    expect(within(items[0]).getByRole('link')).toHaveAttribute('href', `/alerts/${smsAlert.id}`);

    expect(within(items[1]).getByText('Mutesi Diane')).toBeInTheDocument();
    expect(within(items[1]).getByText('Synced online')).toBeInTheDocument();
    expect(within(items[1]).queryByText('Full record pending')).toBeNull();
    expect(within(items[1]).getByText('Reviewed')).toBeInTheDocument();
  });

  it('shows status filters with counts and summary tiles', async () => {
    mockFetch(() => json(list));
    render(<AlertInbox filter="open" />);
    await screen.findAllByRole('listitem');

    const filters = within(screen.getByRole('navigation', { name: 'Filter by status' }));
    expect(filters.getByRole('link', { name: 'Open 4' })).toHaveAttribute('aria-current', 'page');
    expect(filters.getByRole('link', { name: 'Follow-up 2' })).toHaveAttribute('href', '/alerts?status=follow_up');
    expect(filters.getByRole('link', { name: 'All' })).toHaveAttribute('href', '/alerts?status=all');

    const tiles = within(screen.getByRole('region', { name: 'Today at a glance' }));
    expect(tiles.getByText('Active urgent cases').previousSibling).toHaveTextContent('4');
    expect(tiles.getByText('Pending follow-ups').previousSibling).toHaveTextContent('2');
  });

  it('asks the API for every status under All', async () => {
    const fetch = mockFetch(() => json({ ...list, alerts: [] }));
    render(<AlertInbox filter="all" />);
    expect(await screen.findByText('No alerts.')).toBeInTheDocument();
    expect(fetch.mock.calls[0][0]).toBe('/api/alerts');
  });

  it('polls every 10 seconds and keeps the last alerts when a refresh fails', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    let call = 0;
    const fetch = mockFetch(() => {
      call += 1;
      if (call === 2) throw new TypeError('offline');
      return json(call === 1 ? { ...list, alerts: [internetAlert] } : list);
    });
    render(<AlertInbox filter="open" />);
    await screen.findByText('Mutesi Diane');

    await act(() => vi.advanceTimersByTimeAsync(10_000));
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(screen.getByRole('status')).toHaveTextContent('Could not refresh');
    expect(screen.getByText('Mutesi Diane')).toBeInTheDocument();

    // The next poll brings the new SMS alert in at the top and clears the warning.
    await act(() => vi.advanceTimersByTimeAsync(10_000));
    expect(await screen.findByText('Patient P0412')).toBeInTheDocument();
    expect(screen.queryByRole('status')).toBeNull();
  });
});

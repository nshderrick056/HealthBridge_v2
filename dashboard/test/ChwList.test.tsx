import { render, screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { ChwList } from '@/components/ChwList';
import type { Chw } from '@/lib/types';
import { json, mockFetch } from './helpers';

const chw = (over: Partial<Chw>): Chw => ({
  id: 'c1',
  name: 'Claudine M.',
  chwRole: 'asm',
  phone: '+250780000101',
  village: 'Nyamata',
  lastSyncAt: new Date(Date.now() - 5 * 60_000).toISOString(),
  pendingCount: 0,
  ...over,
});

describe('ChwList', () => {
  it('shows each CHW with last sync and pending count, flagging stale phones', async () => {
    const fetch = mockFetch(() =>
      json({
        chws: [
          chw({}),
          chw({ id: 'c2', name: 'Jean Bosco', chwRole: 'binome', lastSyncAt: null, pendingCount: 2 }),
          chw({ id: 'c3', name: 'Aline U.', lastSyncAt: new Date(Date.now() - 3 * 86_400_000).toISOString() }),
        ],
      }),
    );
    render(<ChwList />);

    const rows = await screen.findAllByRole('row');
    expect(fetch.mock.calls[0][0]).toBe('/api/chws');
    expect(rows).toHaveLength(4); // header + 3

    expect(within(rows[1]).getByText('5 min ago')).toBeInTheDocument();
    expect(within(rows[1]).getByText('ASM')).toBeInTheDocument();
    expect(within(rows[2]).getByText('Never')).toHaveClass('text-warning');
    expect(within(rows[2]).getByText('2')).toBeInTheDocument();
    expect(within(rows[3]).getByText('3 d ago').closest('td')).toHaveClass('text-warning');
  });
});

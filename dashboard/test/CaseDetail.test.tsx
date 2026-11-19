import { fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { CaseDetail } from '@/components/CaseDetail';
import type { AlertDetail } from '@/lib/types';
import { detail, json, mockFetch } from './helpers';

const id = detail().id;

/** Serves GET /api/alerts/:id from `state` and applies PATCHes to it, like the API would. */
function fakeApi(start: AlertDetail, patchStatus = 200) {
  let state = start;
  const fetch = mockFetch((_url, init) => {
    if (init?.method === 'PATCH') {
      if (patchStatus !== 200) return json({ error: 'status_changed' }, patchStatus);
      const { status, note } = JSON.parse(String(init.body));
      state = {
        ...state,
        status,
        next: status === 'resolved' ? [] : ['resolved'],
        events: [...state.events, { id: '1', fromStatus: state.status, toStatus: status, note: note ?? null, actor: 'Demo Supervisor', createdAt: new Date().toISOString() }],
      };
      return json({ id, status });
    }
    return json(state);
  });
  const patches = () =>
    fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([url, init]) => [url, JSON.parse(String(init!.body))]);
  return { fetch, patches };
}

const button = (name: string) => screen.getByRole('button', { name });

describe('CaseDetail', () => {
  it('shows what the SMS carried and says the full record is pending', async () => {
    fakeApi(detail());
    render(<CaseDetail id={id} />);

    expect(await screen.findByText('Name not received yet')).toBeInTheDocument();
    expect(screen.getByText('Urgent case · P0412')).toBeInTheDocument();
    expect(screen.getByText(/Only the SMS alert has arrived/)).toBeInTheDocument();
    expect(within(screen.getByRole('region', { name: 'Key warning indicators' })).getByText('Heavy bleeding')).toBeInTheDocument();
    expect(screen.getByText('38.9 °C')).toBeInTheDocument();
    expect(screen.getByText('32 weeks')).toBeInTheDocument();
    expect(screen.getByText('SMS fallback')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: '+250780000101' })).toHaveAttribute('href', 'tel:+250780000101');
  });

  it('marks a case reviewed and shows it in the history', async () => {
    const api = fakeApi(detail());
    render(<CaseDetail id={id} />);
    const user = userEvent.setup();

    await user.type(await screen.findByLabelText(/Note for the case history/), 'Called the CHW');
    await user.click(button('Mark as reviewed'));

    expect(api.patches()).toEqual([[`/api/alerts/${id}`, { status: 'reviewed', note: 'Called the CHW' }]]);
    expect(await screen.findByText('Called the CHW')).toBeInTheDocument();
    expect(screen.getByText('by Demo Supervisor')).toBeInTheDocument();
    expect(button('Mark as reviewed')).toBeDisabled();
  });

  it('only enables the moves the API allows next', async () => {
    fakeApi(detail({ status: 'follow_up', next: ['escalated', 'resolved'] }));
    render(<CaseDetail id={id} />);
    await screen.findByText('Name not received yet');

    expect(button('Mark as reviewed')).toBeDisabled();
    expect(button('Request follow-up')).toBeDisabled();
    expect(button('Escalate case')).toBeEnabled();
    expect(button('Mark resolved')).toBeEnabled();
  });

  it('a follow-up request needs a date, which goes into the note', async () => {
    const api = fakeApi(detail());
    render(<CaseDetail id={id} />);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: 'Request follow-up' }));
    await user.click(button('Send follow-up request'));
    expect(screen.getByRole('alert')).toHaveTextContent('Choose a follow-up date.');
    expect(api.patches()).toEqual([]);

    fireEvent.change(screen.getByLabelText('Follow up by'), { target: { value: '2026-10-30' } });
    await user.click(button('Send follow-up request'));
    expect(api.patches()).toEqual([[`/api/alerts/${id}`, { status: 'follow_up', note: 'Follow up by 30 Oct 2026' }]]);
  });

  it('asks before resolving, and a resolved case offers no actions', async () => {
    const api = fakeApi(detail());
    render(<CaseDetail id={id} />);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: 'Mark resolved' }));
    expect(api.patches()).toEqual([]);
    await user.click(button('Resolve case'));

    expect(await screen.findByText('This case is resolved and closed.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Mark as reviewed' })).toBeNull();
  });

  it('explains a clash with another supervisor and reloads the case', async () => {
    const api = fakeApi(detail(), 409);
    render(<CaseDetail id={id} />);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: 'Escalate case' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Someone else changed this case');
    const gets = api.fetch.mock.calls.filter(([, init]) => init?.method !== 'PATCH');
    expect(gets.length).toBe(2);
  });

  it('says so when the case is not in this health centre', async () => {
    mockFetch(() => json({ error: 'not_found' }, 404));
    render(<CaseDetail id={id} />);
    expect(await screen.findByText(/does not exist or belongs to another health centre/)).toBeInTheDocument();
  });
});

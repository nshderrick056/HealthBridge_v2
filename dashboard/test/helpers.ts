import { vi } from 'vitest';
import type { AlertDetail, AlertSummary } from '@/lib/types';

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

/** Replaces global fetch; the handler gets the URL as a string and the init. */
export function mockFetch(handler: (url: string, init?: RequestInit) => Response | Promise<Response>) {
  const fn = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => handler(String(input), init));
  vi.stubGlobal('fetch', fn);
  return fn;
}

const ago = (min: number) => new Date(Date.now() - min * 60_000).toISOString();

export const smsAlert: AlertSummary = {
  id: '6f0c1c1e-0000-4000-8000-000000000001',
  status: 'new',
  channel: 'sms',
  createdAt: ago(6),
  ackedToChwAt: null,
  isPartial: true,
  visit: { id: 'v1', type: 'maternal', recordedAt: ago(8) },
  patient: { shortId: 'P0412', name: null },
  chw: { id: 'c1', name: 'Claudine M.' },
  village: 'Nyamata',
  dangerSigns: ['Heavy bleeding', 'Convulsions'],
};

export const internetAlert: AlertSummary = {
  ...smsAlert,
  id: '6f0c1c1e-0000-4000-8000-000000000002',
  status: 'reviewed',
  channel: 'internet',
  createdAt: ago(24),
  isPartial: false,
  visit: { id: 'v2', type: 'child', recordedAt: ago(25) },
  patient: { shortId: 'P0007', name: 'Mutesi Diane' },
  chw: { id: 'c2', name: 'Jean Bosco' },
  dangerSigns: ['Vomits everything'],
};

export const detail = (over: Partial<AlertDetail> = {}): AlertDetail => ({
  id: smsAlert.id,
  status: 'new',
  channel: 'sms',
  createdAt: ago(6),
  ackedToChwAt: null,
  next: ['reviewed', 'escalated', 'follow_up', 'resolved'],
  visit: {
    id: 'v1',
    shortCode: '7f3c9a21',
    type: 'maternal',
    answers: { signs: ['HB'], vitals: ['T389', 'G32'] },
    notes: null,
    followUpOn: null,
    recordedAt: ago(8),
    receivedAt: ago(6),
    source: 'sms',
    isPartial: true,
  },
  patient: { shortId: 'P0412', name: null, sex: null, birthDate: null, ageEstimate: null, village: 'Nyamata' },
  chw: { id: 'c1', name: 'Claudine M.', phone: '+250780000101' },
  dangerSigns: [{ code: 'HB', label: 'Heavy bleeding' }],
  events: [],
  ...over,
});

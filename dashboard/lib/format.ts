import type { AlertStatus, VisitType } from './types';

export const STATUS_LABEL: Record<AlertStatus, string> = {
  new: 'New',
  reviewed: 'Reviewed',
  escalated: 'Escalated',
  follow_up: 'Follow-up',
  resolved: 'Resolved',
};
export const STATUS_ORDER: AlertStatus[] = ['new', 'reviewed', 'escalated', 'follow_up', 'resolved'];

// Inbox filters: 'open' (the default) is everything not resolved.
export const FILTERS = ['open', ...STATUS_ORDER, 'all'] as const;
export type Filter = (typeof FILTERS)[number];
export const FILTER_LABEL: Record<Filter, string> = { open: 'Open', ...STATUS_LABEL, all: 'All' };

/** FR-12: a new alert shows within 10 s. */
export const POLL_MS = 10_000;

export const VISIT_TYPE_LABEL: Record<VisitType, string> = {
  maternal: 'Maternal',
  child: 'Child',
  malaria: 'Malaria',
  nutrition: 'Nutrition',
};

// Rwanda has one time zone and no DST; showing it explicitly keeps server-rendered and browser times equal.
const TZ = 'Africa/Kigali';
const clock = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, hour: '2-digit', minute: '2-digit' });
const dayClock = new Intl.DateTimeFormat('en-GB', {
  timeZone: TZ,
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
});
const day = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, day: 'numeric', month: 'short', year: 'numeric' });

export const formatClock = (d: Date | string) => clock.format(new Date(d));
export const formatDateTime = (d: Date | string) => dayClock.format(new Date(d));
export const formatDate = (d: Date | string) => day.format(new Date(d));

export function timeAgo(iso: string, now = Date.now()) {
  const s = Math.max(0, Math.round((now - new Date(iso).getTime()) / 1000));
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} h ago`;
  return `${Math.floor(h / 24)} d ago`;
}

const ANSWER_LABEL: Record<string, string> = {
  symptoms: 'Reported symptoms',
  temperature: 'Temperature',
  general_condition: 'General condition',
};

// SMS vitals are a letter and digits (Backend Schema §3): T389 is 38.9 °C, G32 is 32 weeks of gestation.
function describeVital(v: string): [string, string] {
  const n = v.slice(1);
  if (v[0] === 'T' && /^\d{3}$/.test(n)) return ['Temperature', `${n.slice(0, 2)}.${n[2]} °C`];
  if (v[0] === 'G') return ['Gestation', `${n} weeks`];
  return ['Vital', v];
}

/** Visit answers as label/value rows. Danger signs (`signs`) are shown on their own, so they are skipped. */
export function describeAnswers(answers: Record<string, unknown>): [string, string][] {
  const rows: [string, string][] = [];
  for (const [key, value] of Object.entries(answers)) {
    if (key === 'signs' || value === null || value === undefined || value === '') continue;
    if (key === 'vitals' && Array.isArray(value)) {
      rows.push(...value.map((v) => describeVital(String(v))));
    } else if (key === 'temperature' && typeof value === 'number') {
      rows.push(['Temperature', `${value} °C`]);
    } else {
      const label = ANSWER_LABEL[key] ?? key.charAt(0).toUpperCase() + key.slice(1).replaceAll('_', ' ');
      rows.push([label, Array.isArray(value) ? value.join(', ') : typeof value === 'object' ? JSON.stringify(value) : String(value)]);
    }
  }
  return rows;
}

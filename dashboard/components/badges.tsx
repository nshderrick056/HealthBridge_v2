import { STATUS_LABEL } from '@/lib/format';
import type { AlertStatus, Channel } from '@/lib/types';
import { SmsIcon, WifiIcon } from './icons';

// Red while the case needs action, amber for follow-up, green once someone has it in hand.
const STATUS_STYLE: Record<AlertStatus, string> = {
  new: 'bg-red-tint text-red',
  escalated: 'bg-red-tint text-red',
  follow_up: 'bg-amber-tint text-warning',
  reviewed: 'bg-teal-tint text-brand',
  resolved: 'bg-neutral-tint text-muted',
};

const pill = 'inline-flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1 text-sm font-semibold';

export function StatusPill({ status }: { status: AlertStatus }) {
  return (
    <span className={`${pill} ${STATUS_STYLE[status]}`}>
      <span aria-hidden className="size-2 rounded-full bg-current" />
      {STATUS_LABEL[status]}
    </span>
  );
}

export function ChannelBadge({ channel }: { channel: Channel }) {
  return channel === 'sms' ? (
    <span className={`${pill} bg-neutral-tint text-muted`}>
      <SmsIcon /> SMS fallback
    </span>
  ) : (
    <span className={`${pill} bg-teal-tint text-brand`}>
      <WifiIcon /> Synced online
    </span>
  );
}

export function PendingTag() {
  return <span className={`${pill} bg-amber-tint text-warning`}>Full record pending</span>;
}

/** Initials in a circle; red while a case needs action, amber for follow-up. */
export function Avatar({ name, tone = 'plain' }: { name: string; tone?: 'plain' | 'urgent' | 'due' | 'lime' }) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const text = parts.length ? (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase() : '?';
  const style = {
    plain: 'bg-teal-tint text-brand',
    urgent: 'bg-red text-white',
    due: 'bg-amber-mark text-warning',
    lime: 'bg-lime text-ink',
  }[tone];
  return (
    <span aria-hidden className={`flex size-11 shrink-0 items-center justify-center rounded-full text-[15px] font-semibold ${style}`}>
      {text}
    </span>
  );
}

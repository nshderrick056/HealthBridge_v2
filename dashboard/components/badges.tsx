import { STATUS_LABEL } from '@/lib/format';
import type { AlertStatus, Channel } from '@/lib/types';
import { SmsIcon, WifiIcon } from './icons';

const STATUS_STYLE: Record<AlertStatus, string> = {
  new: 'bg-red-tint text-red',
  reviewed: 'bg-green-tint text-green',
  escalated: 'bg-amber-tint text-warning',
  follow_up: 'bg-teal-tint text-teal',
  resolved: 'bg-neutral-tint text-muted',
};

export function StatusPill({ status }: { status: AlertStatus }) {
  return (
    <span
      className={`inline-flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${STATUS_STYLE[status]}`}
    >
      <span aria-hidden className="size-1.5 rounded-full bg-current" />
      {STATUS_LABEL[status]}
    </span>
  );
}

export function ChannelBadge({ channel }: { channel: Channel }) {
  return channel === 'sms' ? (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-neutral-tint px-3 py-1 text-xs font-semibold text-muted">
      <SmsIcon /> SMS fallback
    </span>
  ) : (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-green-tint px-3 py-1 text-xs font-semibold text-green">
      <WifiIcon /> Synced online
    </span>
  );
}

export function PendingTag() {
  return (
    <span className="inline-flex items-center rounded-full bg-amber-tint px-3 py-1 text-xs font-semibold text-warning">
      Full record pending
    </span>
  );
}

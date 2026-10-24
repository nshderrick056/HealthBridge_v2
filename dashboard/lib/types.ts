// Response shapes of the supervisor API (server/src/supervisor/routes.ts).

export type AlertStatus = 'new' | 'reviewed' | 'escalated' | 'follow_up' | 'resolved';
export type Channel = 'internet' | 'sms';
export type VisitType = 'maternal' | 'child' | 'malaria' | 'nutrition';

export type AlertSummary = {
  id: string;
  status: AlertStatus;
  channel: Channel;
  createdAt: string;
  ackedToChwAt: string | null;
  isPartial: boolean;
  visit: { id: string; type: VisitType; recordedAt: string };
  patient: { shortId: string; name: string | null };
  chw: { id: string; name: string };
  village: string | null;
  dangerSigns: string[];
};

export type AlertList = { alerts: AlertSummary[]; counts: Record<AlertStatus, number> };

export type AlertEvent = {
  id: string;
  fromStatus: AlertStatus | null;
  toStatus: AlertStatus;
  note: string | null;
  actor: string | null;
  createdAt: string;
};

export type AlertDetail = {
  id: string;
  status: AlertStatus;
  channel: Channel;
  createdAt: string;
  ackedToChwAt: string | null;
  next: AlertStatus[];
  visit: {
    id: string;
    shortCode: string;
    type: VisitType;
    answers: Record<string, unknown>;
    notes: string | null;
    followUpOn: string | null;
    recordedAt: string;
    receivedAt: string;
    source: 'sync' | 'sms';
    isPartial: boolean;
  };
  patient: {
    shortId: string;
    name: string | null;
    sex: 'F' | 'M' | null;
    birthDate: string | null;
    ageEstimate: number | null;
    village: string | null;
  };
  chw: { id: string; name: string; phone: string };
  dangerSigns: { code: string; label: string }[];
  events: AlertEvent[];
};

export type Chw = {
  id: string;
  name: string;
  chwRole: 'asm' | 'binome' | null;
  phone: string;
  village: string | null;
  lastSyncAt: string | null;
  pendingCount: number;
};

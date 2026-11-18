// Supervisor history pages: what GET /chws/:id, /patients and /patients/:id return.
import type { VisitType } from './types';

export type HistoryVisit = {
  id: string;
  type: VisitType | null;
  recordedAt: string | null;
  receivedAt: string | null;
  isUrgent: boolean;
  isPartial: boolean;
  dangerSigns: string[];
  temperature: number | null;
  condition: string | null;
  symptoms: string | null;
  notes: string | null;
  followUpOn: string | null;
  patient?: { id: string; shortId: string | null; name: string | null };
};

export type PatientRow = {
  id: string;
  shortId: string | null;
  name: string | null;
  village: string | null;
  sex: 'F' | 'M' | null;
  ageEstimate: number | null;
  birthDate: string | null;
  chw: { id: string; name: string | null };
  lastVisitAt: string | null;
  lastVisitUrgent: boolean;
  visitCount: number;
};

export type ChwHistory = {
  chw: { id: string; name: string; chwRole: string | null; phone: string; village: string | null };
  visits: HistoryVisit[];
};

export type PatientHistory = {
  patient: Omit<PatientRow, 'chw' | 'lastVisitAt' | 'lastVisitUrgent' | 'visitCount'> & { archived: boolean };
  chw: { id: string; name: string | null; phone: string | null };
  visits: HistoryVisit[];
};

/** "32 years · Female", from what is known. */
export function ageSex(p: { sex: 'F' | 'M' | null; ageEstimate: number | null; birthDate: string | null }) {
  const age = p.birthDate
    ? Math.floor((Date.now() - new Date(p.birthDate).getTime()) / (365.25 * 24 * 3_600_000))
    : p.ageEstimate;
  return [age != null ? `${age} years` : null, p.sex === 'F' ? 'Female' : p.sex === 'M' ? 'Male' : null]
    .filter(Boolean)
    .join(' · ');
}

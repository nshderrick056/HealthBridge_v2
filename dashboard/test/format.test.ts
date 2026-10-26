import { describe, expect, it } from 'vitest';
import { describeAnswers, formatClock, timeAgo } from '@/lib/format';

describe('format', () => {
  it('reads SMS vitals and app answers as labelled rows, without the danger-sign codes', () => {
    expect(describeAnswers({ signs: ['HB'], vitals: ['T389', 'G32', 'W123'] })).toEqual([
      ['Temperature', '38.9 °C'],
      ['Gestation', '32 weeks'],
      ['Vital', 'W123'],
    ]);
    expect(describeAnswers({ symptoms: 'Headache', temperature: 39.2, general_condition: 'Needs attention', notes_extra: '' })).toEqual([
      ['Reported symptoms', 'Headache'],
      ['Temperature', '39.2 °C'],
      ['General condition', 'Needs attention'],
    ]);
  });

  it('gives relative times in plain words', () => {
    const now = Date.parse('2026-10-06T10:00:00Z');
    expect(timeAgo('2026-10-06T09:59:30Z', now)).toBe('just now');
    expect(timeAgo('2026-10-06T09:54:00Z', now)).toBe('6 min ago');
    expect(timeAgo('2026-10-06T07:00:00Z', now)).toBe('3 h ago');
    expect(timeAgo('2026-10-04T10:00:00Z', now)).toBe('2 d ago');
  });

  it('shows clock times in Kigali time', () => {
    expect(formatClock('2026-10-06T07:35:00Z')).toBe('09:35');
  });
});

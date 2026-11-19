import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { PatientHistory } from '@/components/PatientHistory';
import { json, mockFetch } from './helpers';

describe('PatientHistory', () => {
  it('shows the patient, their CHW and each visit with what was recorded', async () => {
    const fetch = mockFetch(() =>
      json({
        patient: { id: 'p1', shortId: 'P0412', name: 'Uwase Marie', village: 'Nyamata', sex: 'F', ageEstimate: 32, birthDate: null, archived: false },
        chw: { id: 'c1', name: 'Claudine M.', phone: '+250780000101' },
        visits: [
          { id: 'v1', type: 'maternal', recordedAt: '2026-11-10T08:00:00Z', receivedAt: null, isUrgent: true, isPartial: false, dangerSigns: ['Heavy bleeding'], temperature: 38.9, condition: 'Needs attention', symptoms: 'Headache', notes: 'Referred', followUpOn: null },
        ],
      }),
    );
    render(<PatientHistory id="p1" />);

    expect(await screen.findByRole('heading', { name: 'Uwase Marie' })).toBeInTheDocument();
    expect(fetch.mock.calls[0][0]).toBe('/api/patients/p1');
    expect(screen.getByText(/32 years · Female · Nyamata · P0412/)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Claudine M.' })).toHaveAttribute('href', '/chws/c1');
    expect(screen.getByText('Heavy bleeding')).toBeInTheDocument();
    expect(screen.getByText('38.9 °C')).toBeInTheDocument();
    expect(screen.getByText('Referred')).toBeInTheDocument();
    expect(screen.getByText('The latest visit was urgent.')).toBeInTheDocument();
  });

  it('says so when the patient belongs to another centre', async () => {
    mockFetch(() => json({ error: 'not_found' }, 404));
    render(<PatientHistory id="p9" />);
    expect(await screen.findByText(/belongs to another health centre/)).toBeInTheDocument();
  });
});

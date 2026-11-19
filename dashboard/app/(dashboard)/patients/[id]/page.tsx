import type { Metadata } from 'next';
import { PatientHistory } from '@/components/PatientHistory';

export const metadata: Metadata = { title: 'Patient' };

export default async function PatientPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <PatientHistory id={id} />;
}

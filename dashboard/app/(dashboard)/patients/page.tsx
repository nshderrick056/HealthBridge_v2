import type { Metadata } from 'next';
import { PatientList } from '@/components/PatientList';

export const metadata: Metadata = { title: 'Patients' };

export default function PatientsPage() {
  return <PatientList />;
}

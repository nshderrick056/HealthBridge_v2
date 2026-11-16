import type { Metadata } from 'next';
import { ResetRequests } from '@/components/admin/ResetRequests';

export const metadata: Metadata = { title: 'Reset requests' };

export default function ResetsPage() {
  return <ResetRequests />;
}

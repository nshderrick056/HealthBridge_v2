import type { Metadata } from 'next';
import { CentreDetail } from '@/components/admin/CentreDetail';

export const metadata: Metadata = { title: 'Health centre' };

export default async function CentrePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CentreDetail id={id} />;
}

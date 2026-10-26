import type { Metadata } from 'next';
import { CaseDetail } from '@/components/CaseDetail';

export const metadata: Metadata = { title: 'Case' };

export default async function CasePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CaseDetail id={id} />;
}

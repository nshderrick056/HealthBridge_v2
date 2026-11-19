import type { Metadata } from 'next';
import { MemberDetail } from '@/components/admin/MemberDetail';

export const metadata: Metadata = { title: 'Member' };

export default async function MemberPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <MemberDetail id={id} />;
}

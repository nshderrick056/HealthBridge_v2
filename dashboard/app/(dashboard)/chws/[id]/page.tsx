import type { Metadata } from 'next';
import { ChwHistory } from '@/components/ChwHistory';

export const metadata: Metadata = { title: 'CHW' };

export default async function ChwPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ChwHistory id={id} />;
}

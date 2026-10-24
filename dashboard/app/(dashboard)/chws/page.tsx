import type { Metadata } from 'next';
import { ChwList } from '@/components/ChwList';

export const metadata: Metadata = { title: 'CHWs' };

export default function ChwsPage() {
  return <ChwList />;
}

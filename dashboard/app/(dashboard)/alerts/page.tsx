import type { Metadata } from 'next';
import { AlertInbox } from '@/components/AlertInbox';
import { FILTERS, type Filter } from '@/lib/format';

export const metadata: Metadata = { title: 'Alerts' };

export default async function AlertsPage({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const { status } = await searchParams;
  const filter = FILTERS.includes(status as Filter) ? (status as Filter) : 'open';
  return <AlertInbox filter={filter} />;
}

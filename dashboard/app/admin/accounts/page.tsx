import type { Metadata } from 'next';
import { NewAccount } from '@/components/admin/NewAccount';

export const metadata: Metadata = { title: 'Add an account' };

export default function AccountsPage() {
  return <NewAccount />;
}

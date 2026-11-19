import type { Metadata } from 'next';
import { NewAccount } from '@/components/admin/NewAccount';

export const metadata: Metadata = { title: 'Add a member' };

export default function NewMemberPage() {
  return <NewAccount />;
}

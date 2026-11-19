import type { Metadata } from 'next';
import { Centres } from '@/components/admin/Centres';

export const metadata: Metadata = { title: 'Health centres' };

export default function CentresPage() {
  return <Centres />;
}

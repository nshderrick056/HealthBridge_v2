import type { NextRequest } from 'next/server';
import { forward } from '@/lib/proxy';

type Ctx = { params: Promise<{ path: string[] }> };

export async function GET(req: NextRequest, { params }: Ctx) {
  return forward(req, (await params).path);
}

export async function PATCH(req: NextRequest, { params }: Ctx) {
  return forward(req, (await params).path);
}

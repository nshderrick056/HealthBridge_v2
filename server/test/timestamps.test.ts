import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createPrisma, type Db } from '../src/db';

// Runs against a real Postgres (CI service, or the dev DB from .env); the rows it writes are deleted.
const url = process.env.DATABASE_URL;

describe.skipIf(!url)('timestamps against Postgres', () => {
  let db: Db;
  const ids: bigint[] = [];

  beforeAll(() => {
    db = createPrisma(url);
  });

  afterAll(async () => {
    if (!db) return;
    await db.sms_messages.deleteMany({ where: { id: { in: ids } } });
    await db.$disconnect();
  });

  // The pg adapter sends dates without a UTC offset, so a database whose timezone is not UTC
  // stored every time shifted by its offset (2 h on a Kigali/Johannesburg machine).
  it('stores the real instant whatever the database timezone', async () => {
    const at = new Date('2026-11-01T18:49:01.035Z');
    const row = await db.sms_messages.create({
      data: { direction: 'in', phone: 'tz-test', raw_text: 'tz-test', status: 'rejected', created_at: at },
    });
    ids.push(row.id);
    const [stored] = await db.$queryRaw<{ ms: number }[]>`
      select (extract(epoch from created_at) * 1000)::float8 as ms from sms_messages where id = ${row.id}`;
    expect(stored.ms).toBe(at.getTime());
    const back = await db.sms_messages.findUniqueOrThrow({ where: { id: row.id } });
    expect(back.created_at.getTime()).toBe(at.getTime());
  });
});

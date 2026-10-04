import { Test } from '@nestjs/testing';
import { WorkshopService } from '../src/modules/workshop/workshop.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [WorkshopService] }).compile();
  return mod.get(WorkshopService);
}

function makeFreeApproved(ws: WorkshopService, author: string, n: number) {
  for (let i = 0; i < n; i++) {
    const it = ws.create(`free-${i}`, author, { price: 0 });
    ws.submit(it.id);
    ws.review(it.id, true);
    ws.transition(it.id, 'Published');
  }
}

describe('workshop Tier2-4', () => {
  test('5-free rule: платные запрещены до 5 approved free', async () => {
    const ws = await setup();
    expect(() => ws.create('paid-early', 'newbie', { price: 100 })).toThrow();
    makeFreeApproved(ws, 'newbie', 5);
    const paid = ws.create('paid-ok', 'newbie', { price: 100 });
    expect(paid.price).toBe(100);
  });

  test('flow Draft->Pending->Approved->Published + reject требует reason', async () => {
    const ws = await setup();
    const it = ws.create('theme-a', 'author-a');
    expect(() => ws.transition(it.id, 'Published')).toThrow();
    ws.submit(it.id);
    expect(ws.get(it.id).state).toBe('Pending');
    expect(() => ws.review(it.id, false)).toThrow(); // reason required
    ws.review(it.id, false, 'low quality');
    expect(ws.get(it.id).state).toBe('Rejected');
    expect(ws.get(it.id).rejectReason).toBe('low quality');
  });

  test('новая версия после publish снова в Pending (re-moderation)', async () => {
    const ws = await setup();
    const it = ws.create('theme-b', 'author-b');
    ws.submit(it.id);
    ws.review(it.id, true);
    ws.transition(it.id, 'Published');
    const v2 = ws.createVersion(it.id, 'author-b', { title: 'theme-b v2' });
    expect(v2.version).toBe(2);
    expect(v2.state).toBe('Pending');
  });

  test('preview без покупки: только safe-data', async () => {
    const ws = await setup();
    const it = ws.create('theme-c', 'author-c', { description: 'x'.repeat(500) });
    const p = ws.preview(it.id);
    expect(p.price).toBe(0);
    expect(p.preview.excerpt.length).toBeLessThanOrEqual(280);
    expect(p.preview.hasMore).toBe(true);
    expect('description' in p).toBe(false);
  });

  test('purchase: free — грант, paid — tx buyer->author', async () => {
    const ws = await setup();
    const free = ws.create('free-item', 'author-d');
    ws.submit(free.id);
    ws.review(free.id, true);
    ws.transition(free.id, 'Published');
    const g = ws.purchase(free.id, 'buyer-1');
    expect(g.granted).toBe(true);
    expect(g.tx).toBeNull();

    makeFreeApproved(ws, 'author-e', 5);
    const paid = ws.create('paid-item', 'author-e', { price: 50 });
    ws.submit(paid.id);
    ws.review(paid.id, true);
    ws.transition(paid.id, 'Published');
    const r = ws.purchase(paid.id, 'buyer-2');
    expect(r.tx).toMatchObject({ from: 'buyer-2', to: 'author-e', amount: 50 });
    expect(() => ws.purchase(paid.id, 'author-e')).toThrow(); // автор уже владеет
  });
});

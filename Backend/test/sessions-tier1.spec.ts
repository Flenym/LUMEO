import { Test } from '@nestjs/testing';
import { SessionsService } from '../src/modules/sessions/sessions.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [SessionsService] }).compile();
  return mod.get(SessionsService);
}

function makeChain(svc: SessionsService, creator = 'creator') {
  const s = svc.create({ title: 'Evening ranked', game: 'Valorant', mode: 'Ranked', slots: 4, creatorId: creator });
  svc.transition(s.id, 'Inviting');
  svc.transition(s.id, 'Waiting');
  svc.transition(s.id, 'Ready');
  return s;
}

describe('sessions Tier1', () => {
  test('create валидирует слоты 2..10 и поля', async () => {
    const svc = await setup();
    expect(() => svc.create({ title: 'x', game: 'CS2', slots: 1, creatorId: 'c' })).toThrow();
    expect(() => svc.create({ title: 'x', game: 'CS2', slots: 11, creatorId: 'c' })).toThrow();
    const s = svc.create({
      title: 'duo',
      game: 'CS2',
      mode: 'Duo',
      slots: 2,
      scheduledAt: '2026-10-04T18:00:00.000Z',
      comment: 'go go',
      creatorId: 'c',
      invites: ['p2'],
    });
    expect(s.mode).toBe('Duo');
    expect(s.invites).toHaveLength(1);
    expect(s.invites[0]).toMatchObject({ kind: 'session-invite', to: 'p2' });
  });

  test('полная цепочка Draft→Inviting→Waiting→Ready→Live→Paused→Live→Finished', async () => {
    const svc = await setup();
    const s = makeChain(svc);
    const live = svc.transition(s.id, 'Live');
    expect(live.startedAt).not.toBeNull(); // joining→Live запускает таймер
    expect(live.banner).not.toBeNull(); // banner-данные проставлены
    svc.transition(s.id, 'Paused');
    svc.transition(s.id, 'Live');
    const fin = svc.finish(s.id, 'creator');
    expect(fin.state).toBe('Finished');
    expect(fin.finishedAt).not.toBeNull();
  });

  test('невалидный переход Draft→Live запрещён', async () => {
    const svc = await setup();
    const s = svc.create({ title: 't', game: 'CS2', creatorId: 'c' });
    try {
      svc.transition(s.id, 'Live');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'INVALID_TRANSITION' } });
    }
  });

  test('capacity: слоты 2 → третий не влезает', async () => {
    const svc = await setup();
    const s = svc.create({ title: 'duo', game: 'CS2', slots: 2, creatorId: 'c' });
    svc.transition(s.id, 'Inviting');
    svc.join(s.id, 'p2');
    try {
      svc.join(s.id, 'p3');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'SESSION_FULL' } });
    }
  });

  test('join в Finished/Cancelled запрещён', async () => {
    const svc = await setup();
    const s = makeChain(svc);
    svc.transition(s.id, 'Live');
    svc.transition(s.id, 'Finished', 'creator');
    try {
      svc.join(s.id, 'late');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'SESSION_CLOSED' } });
    }
    const s2 = svc.create({ title: 't2', game: 'CS2', creatorId: 'c' });
    svc.transition(s2.id, 'Cancelled', 'c');
    expect(() => svc.invite(s2.id, 'c', 'x')).toThrow();
  });

  test('invite — спец-объект, не текст', async () => {
    const svc = await setup();
    const s = svc.create({ title: 't', game: 'CS2', creatorId: 'c' });
    const inv = svc.invite(s.id, 'c', 'p9');
    expect(inv.kind).toBe('session-invite');
    expect(inv).not.toHaveProperty('text');
    expect(inv).toMatchObject({ sessionId: s.id, from: 'c', to: 'p9', status: 'pending' });
    svc.respond(s.id, 'p9', true);
    expect(svc.get(s.id).participants.find((p) => p.userId === 'p9')?.status).toBe('accepted');
    // ready / away / leave
    svc.setReady(s.id, 'p9', 'away');
    expect(svc.get(s.id).participants.find((p) => p.userId === 'p9')?.status).toBe('away');
    svc.leave(s.id, 'p9');
    expect(svc.get(s.id).participants.find((p) => p.userId === 'p9')?.status).toBe('left');
  });

  test('block запрещает invite; creator-only kick/edit/cancel', async () => {
    const svc = await setup();
    const s = svc.create({ title: 't', game: 'CS2', creatorId: 'c' });
    svc.setBlock('c', 'bad');
    try {
      svc.invite(s.id, 'c', 'bad');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'BLOCKED' } });
    }
    svc.invite(s.id, 'c', 'good');
    try {
      svc.kick(s.id, 'good', 'c');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'FORBIDDEN' } });
    }
    try {
      svc.cancel(s.id, 'good');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'FORBIDDEN' } });
    }
    // creator может всё
    svc.kick(s.id, 'c', 'good');
    expect(svc.get(s.id).participants.find((p) => p.userId === 'good')?.status).toBe('left');
  });

  test('banner + retime от creator', async () => {
    const svc = await setup();
    const s = svc.create({ title: 't', game: 'CS2', creatorId: 'c' });
    const b = svc.setBanner(s.id, 'c', { x: 10, y: 20, startAt: '2026-10-04T18:00:00.000Z' });
    expect(b.banner).toMatchObject({ x: 10, y: 20 });
    const r = svc.retime(s.id, 'c', '2026-10-05T18:00:00.000Z');
    expect(r.scheduledAt).toBe('2026-10-05T18:00:00.000Z');
    try {
      svc.setBanner(s.id, 'stranger', { x: 0, y: 0, startAt: '2026-10-04T18:00:00.000Z' });
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'FORBIDDEN' } });
    }
  });
});

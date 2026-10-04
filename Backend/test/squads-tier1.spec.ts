import { Test } from '@nestjs/testing';
import { SquadsService } from '../src/modules/squads/squads.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [SquadsService] }).compile();
  return mod.get(SquadsService);
}

describe('squads Tier1', () => {
  test('create: owner + поля xp/level/streak', async () => {
    const sq = await setup();
    const s = sq.create('Night Owls', 'owner1', { chatId: 'chat-1' });
    expect(s.members).toEqual([{ userId: 'owner1', role: 'Owner', joinedAt: expect.any(String) }]);
    expect(s).toMatchObject({ xp: 0, level: 1, streak: 0, chatId: 'chat-1', closed: false });
  });

  test('лимит 200: 201-й отклоняется', async () => {
    const sq = await setup();
    const s = sq.create('Big Squad', 'owner1');
    for (let i = 1; i <= 199; i++) sq.addMember(s.id, `m-${i}`);
    expect(sq.get(s.id).members).toHaveLength(200);
    try {
      sq.addMember(s.id, 'm-200');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'SQUAD_FULL' } });
    }
  });

  test('owner-only guard: rename/avatar/assign/remove/close', async () => {
    const sq = await setup();
    const s = sq.create('S', 'owner1');
    sq.addMember(s.id, 'member1');
    for (const fn of [
      () => sq.rename(s.id, 'member1', 'New'),
      () => sq.setAvatar(s.id, 'member1', 'av'),
      () => sq.assignRole(s.id, 'member1', 'member1', 'Admin'),
      () => sq.removeMember(s.id, 'member1', 'member1'),
      () => sq.close(s.id, 'member1'),
    ]) {
      try {
        fn();
        fail('must throw');
      } catch (e) {
        expect(e).toMatchObject({ response: { code: 'OWNER_ONLY' } });
      }
    }
    expect(sq.rename(s.id, 'owner1', 'New Name').name).toBe('New Name');
    expect(sq.assignRole(s.id, 'owner1', 'member1', 'Admin').members.find((m) => m.userId === 'member1')?.role).toBe(
      'Admin',
    );
  });

  test('invite-all создаёт invites всем selected', async () => {
    const sq = await setup();
    const s = sq.create('S', 'owner1');
    const created = sq.inviteAll(s.id, 'owner1', ['u1', 'u2', 'u1']);
    expect(created).toHaveLength(2);
    expect(created[0]).toMatchObject({ squadId: s.id, from: 'owner1', status: 'pending' });
    expect(sq.listInvites(s.id)).toHaveLength(2);
    sq.respondInvite(s.id, created[0].id, true);
    expect(sq.get(s.id).members.some((m) => m.userId === 'u1')).toBe(true);
  });

  test('POST /squads/:id/activity: xp/level/streak поля', async () => {
    const sq = await setup();
    const s = sq.create('S', 'owner1');
    const r = sq.recordActivity(s.id, { xpDelta: 400, playedDate: '2026-10-03' });
    expect(r).toMatchObject({ xp: 400, level: 3, streak: 1, lastActivityDate: '2026-10-03' });
    const r2 = sq.recordActivity(s.id, { xpDelta: 0, playedDate: '2026-10-03' });
    expect(r2.streak).toBe(1); // тот же день — streak держится
  });

  test('close скрывает сквад', async () => {
    const sq = await setup();
    const s = sq.create('S', 'owner1');
    expect(sq.close(s.id, 'owner1')).toEqual({ closed: true });
    expect(() => sq.get(s.id)).toThrow();
    expect(sq.list()).toEqual([]);
  });
});

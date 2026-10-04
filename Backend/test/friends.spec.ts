import { Test } from '@nestjs/testing';
import { FriendsService } from '../src/modules/friends/friends.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [FriendsService] }).compile();
  return mod.get(FriendsService);
}

describe('friends Tier1', () => {
  test('send/wait/accept создаёт дружбу', async () => {
    const f = await setup();
    f.registerUser('a', '@alice_1');
    f.registerUser('b', '@bob_22');
    const r = f.send('a', 'b');
    expect(r.status).toBe('pending');
    const ship = f.accept(r.id, 'b');
    expect(f.areFriends('a', 'b')).toBe(true);
    expect(ship.userA).toBe('a');
  });

  test('decline → cooldown 24ч на повторную заявку', async () => {
    const f = await setup();
    const r = f.send('a', 'b');
    f.decline(r.id, 'b');
    expect(() => f.send('a', 'b')).toThrow();
    try {
      f.send('a', 'b');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'DECLINE_COOLDOWN' } });
    }
  });

  test('block запрещает заявку и разрывает дружбу', async () => {
    const f = await setup();
    const r = f.send('a', 'b');
    f.accept(r.id, 'b');
    expect(f.areFriends('a', 'b')).toBe(true);
    f.block('a', 'b');
    expect(f.areFriends('a', 'b')).toBe(false);
    expect(f.isBlocked('a', 'b')).toBe(true);
    try {
      f.send('b', 'a');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'BLOCKED' } });
    }
    expect(f.unblock('a', 'b')).toEqual({ blocked: false });
  });

  test('favorite/pin/mute отражаются в списке', async () => {
    const f = await setup();
    f.registerUser('a', '@alice_1');
    f.registerUser('b', '@bob_22');
    const r = f.send('a', 'b');
    f.accept(r.id, 'b');
    f.setFavorite('a', 'b', true);
    f.setPinned('a', 'b', true);
    f.setMuted('a', 'b', true);
    const list = f.listFriends('a');
    expect(list.items[0]).toMatchObject({ userId: 'b', favorite: true, pinned: true, muted: true });
  });

  test('поиск по username (с @ и без)', async () => {
    const f = await setup();
    f.registerUser('u1', '@Night_Wolf.7');
    const res = f.searchByUsername('@night_wolf');
    expect(res.length).toBe(1);
    expect(res[0].userId).toBe('u1');
    expect(f.searchByUsername('WOLF')).toHaveLength(1);
    expect(f.searchByUsername('')).toEqual([]);
  });

  test('QR payload userId+code и resolve', async () => {
    const f = await setup();
    const p = f.qrPayload('user-1');
    expect(p.userId).toBe('user-1');
    expect(p.code).toBeDefined();
    expect(f.qrResolve(p.code)).toEqual({ userId: 'user-1' });
    expect(f.qrResolve('nope-code')).toBeNull();
  });

  test('cursor-пагинация друзей', async () => {
    const f = await setup();
    for (const [id, name] of [['a', '@aa_aa'], ['b', '@bb_bb'], ['c', '@cc_cc'], ['d', '@dd_dd']] as const) {
      f.registerUser(id, name);
    }
    for (const to of ['b', 'c', 'd']) f.accept(f.send('a', to).id, to);
    const p1 = f.listFriends('a', { limit: 2, sort: 'name' });
    expect(p1.items).toHaveLength(2);
    expect(p1.nextCursor).not.toBeNull();
    expect(p1.total).toBe(3);
    const p2 = f.listFriends('a', { limit: 2, sort: 'name', cursor: p1.nextCursor as string });
    expect(p2.items).toHaveLength(1);
    expect(p2.nextCursor).toBeNull();
  });

  test('сортировка: pinned всплывает вверх', async () => {
    const f = await setup();
    f.registerUser('a', '@aa_11');
    f.registerUser('b', '@zz_99');
    f.registerUser('c', '@mm_55');
    f.accept(f.send('a', 'b').id, 'b');
    f.accept(f.send('a', 'c').id, 'c');
    f.setPinned('a', 'c', true);
    const list = f.listFriends('a', { sort: 'name' });
    expect(list.items[0].userId).toBe('c');
  });
});

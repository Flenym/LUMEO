import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { HttpExceptionFilter } from '../src/common/filters/http-exception.filter';
import { paginateCursor } from '../src/common/pagination';
import { canInvite, canMessage, canSeeProfile } from '../src/common/engines/permissions.engine';
import { HealthController } from '../src/modules/health/health.controller';
import { VersionController } from '../src/modules/health/version.controller';
import { UsersService } from '../src/modules/users/users.service';
import { FriendsService } from '../src/modules/friends/friends.service';
import { SessionsService } from '../src/modules/sessions/sessions.service';

function runFilter(ex: unknown, requestId: string | null = 'req-1') {
  let captured: unknown = null;
  let statusCode = 0;
  const res = {
    status: (c: number) => {
      statusCode = c;
      return { json: (b: unknown) => (captured = b) };
    },
  };
  const req = { url: '/api/v1/x', headers: {}, requestId };
  const host = { switchToHttp: () => ({ getResponse: () => res, getRequest: () => req }) };
  new HttpExceptionFilter().catch(ex, host as never);
  return { captured: captured as Record<string, unknown>, statusCode };
}

describe('tier1 integration', () => {
  test('error filter: единый формат {code,message,requestId}', async () => {
    const { captured, statusCode } = runFilter(new BadRequestException({ code: 'X_FOO', message: 'bar' }));
    expect(statusCode).toBe(400);
    expect(captured).toMatchObject({ code: 'X_FOO', message: 'bar', requestId: 'req-1' });
    const nf = runFilter(new NotFoundException('gone'));
    expect(nf.statusCode).toBe(404);
    expect(nf.captured).toMatchObject({ code: 'NOT_FOUND', requestId: 'req-1' });
  });

  test('cursor-пагинация helper', async () => {
    const all = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    const p1 = paginateCursor(all, undefined, 2, (x) => x.id);
    expect(p1.items.map((x) => x.id)).toEqual(['a', 'b']);
    expect(p1.nextCursor).toBe('b');
    const p2 = paginateCursor(all, p1.nextCursor, 2, (x) => x.id);
    expect(p2.items.map((x) => x.id)).toEqual(['c']);
    expect(p2.nextCursor).toBeNull();
  });

  test('permissions: block+privacy для invite/message/profile', async () => {
    expect(canInvite({ blocked: true, areFriends: true })).toBe(false);
    expect(canInvite({ blocked: false, areFriends: false, targetPrivacy: { invites: 'friends' } })).toBe(false);
    expect(canInvite({ blocked: false, areFriends: true, targetPrivacy: { invites: 'friends' } })).toBe(true);
    expect(canMessage({ blocked: false, areFriends: false, targetPrivacy: { messages: 'nobody' } })).toBe(false);
    expect(canMessage({ blocked: false, areFriends: false })).toBe(true);
    expect(canSeeProfile({ blocked: true, areFriends: true })).toBe(false);
    expect(canSeeProfile({ blocked: false, areFriends: false })).toBe(true);
  });

  test('users: username-правила, уникальность, поиск', async () => {
    const mod = await Test.createTestingModule({ providers: [UsersService] }).compile();
    const users = mod.get(UsersService);
    const u = users.create('@gamer_01');
    expect(u.username).toBe('gamer_01');
    expect(() => users.create('ab')).toThrow();
    expect(() => users.create('@GAMER_01')).toThrow(); // case-insensitive unique
    expect(users.getByUsername('@Gamer_01').id).toBe(u.id);
    expect(users.searchByUsername('gamer')).toHaveLength(1);
    expect(users.listCursor(undefined, 20).total).toBe(1);
  });

  test('health: {status,version,uptime,wsConnections,db} + /api/v1/version', async () => {
    const mod = await Test.createTestingModule({
      controllers: [HealthController, VersionController],
    }).compile();
    const h = mod.get(HealthController).check();
    expect(h.status).toBe('ok');
    expect(h.version).toBe('0.1.0');
    expect(typeof h.uptime).toBe('number');
    expect(typeof h.wsConnections).toBe('number');
    expect(['configured', 'degraded']).toContain(h.db);
    expect(mod.get(VersionController).version()).toMatchObject({ version: '0.1.0', api: 'v1' });
  });

  test('block запрещает session invite (friends + sessions)', async () => {
    const mod = await Test.createTestingModule({
      providers: [FriendsService, SessionsService],
    }).compile();
    const friends = mod.get(FriendsService);
    const sessions = mod.get(SessionsService);
    friends.block('creator', 'spammer');
    // friends-уровень
    expect(() => friends.send('spammer', 'creator')).toThrow();
    // sessions-уровень (зеркальный реестр блоков)
    const s = sessions.create({ title: 't', game: 'CS2', creatorId: 'creator' });
    sessions.setBlock('creator', 'spammer');
    try {
      sessions.invite(s.id, 'creator', 'spammer');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'BLOCKED' } });
    }
  });
});

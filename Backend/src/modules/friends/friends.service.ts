import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { paginateCursor } from '../../common/pagination';

export type FriendReqStatus = 'pending' | 'accepted' | 'declined';
export type FriendSort = 'activity' | 'name' | 'lastSeen' | 'frequency' | 'pinned' | 'manual';

export interface FriendRequest {
  id: string;
  from: string;
  to: string;
  status: FriendReqStatus;
  createdAt: string;
}

export interface Friendship {
  id: string;
  userA: string;
  userB: string;
  createdAt: string;
  manualOrder: number;
}

export interface FriendView {
  userId: string;
  username: string;
  friendSince: string;
  favorite: boolean;
  pinned: boolean;
  muted: boolean;
  lastSeenAt: string | null;
  interactions: number;
}

export const DECLINE_COOLDOWN_MS = 24 * 60 * 60_000;

function pairKey(a: string, b: string): string {
  return [a, b].sort().join(':');
}

// In-memory репозитории с интерфейсом под замену на TypeORM.
// TODO(db): SQL — таблицы friend_requests (unique(from,to) where pending),
// friendships (unique pair), blocks, friend_flags; decline cooldown — поле declined_at.
@Injectable()
export class FriendsService {
  private reqs = new Map<string, FriendRequest>();
  private friendships = new Map<string, Friendship>(); // pairKey -> friendship
  private blocks = new Set<string>(); // "blocker:blocked"
  private declineCooldown = new Map<string, number>(); // "from:to" -> ts ms (24ч после decline)

  private favorites = new Map<string, Set<string>>(); // userId -> friendIds
  private pins = new Map<string, Set<string>>();
  private mutes = new Map<string, Set<string>>();

  private directory = new Map<string, { userId: string; username: string }>(); // userId -> record
  private usernameToId = new Map<string, string>(); // lower(username без @) -> userId
  private lastSeen = new Map<string, number>(); // userId -> ms
  private interactions = new Map<string, Map<string, number>>(); // userId -> (friendId -> count)
  private qrCodes = new Map<string, string>(); // userId -> code

  // ---- справочник пользователей (для поиска/QR; реальные профили — другой модуль) ----

  registerUser(userId: string, username: string): { userId: string; username: string } {
    const clean = username.trim().replace(/^@/, '');
    this.directory.set(userId, { userId, username: clean });
    this.usernameToId.set(clean.toLowerCase(), userId);
    if (!this.lastSeen.has(userId)) this.lastSeen.set(userId, Date.now());
    return { userId, username: clean };
  }

  touchActivity(userId: string, friendId?: string): void {
    this.lastSeen.set(userId, Date.now());
    if (friendId) {
      let m = this.interactions.get(userId);
      if (!m) {
        m = new Map();
        this.interactions.set(userId, m);
      }
      m.set(friendId, (m.get(friendId) ?? 0) + 1);
    }
  }

  // ---- блокировки ----

  isBlocked(a: string, b: string): boolean {
    return this.blocks.has(`${a}:${b}`) || this.blocks.has(`${b}:${a}`);
  }

  block(blocker: string, blocked: string): { blocked: boolean } {
    if (blocker === blocked) throw new BadRequestException({ code: 'BAD_REQUEST', message: 'cannot block yourself' });
    this.blocks.add(`${blocker}:${blocked}`);
    // Блок разрывает дружбу и снимает pending-заявки в обе стороны.
    this.friendships.delete(pairKey(blocker, blocked));
    for (const r of this.reqs.values()) {
      const between =
        (r.from === blocker && r.to === blocked) || (r.from === blocked && r.to === blocker);
      if (between && r.status === 'pending') r.status = 'declined';
    }
    return { blocked: true };
  }

  unblock(blocker: string, blocked: string): { blocked: boolean } {
    this.blocks.delete(`${blocker}:${blocked}`);
    return { blocked: false };
  }

  // ---- заявки ----

  send(from: string, to: string): FriendRequest {
    if (from === to) throw new BadRequestException({ code: 'BAD_REQUEST', message: 'cannot friend yourself' });
    if (this.isBlocked(from, to)) {
      throw new ForbiddenException({ code: 'BLOCKED', message: 'action forbidden by block' });
    }
    if (this.friendships.has(pairKey(from, to))) {
      throw new BadRequestException({ code: 'ALREADY_FRIENDS', message: 'already friends' });
    }
    const pending = [...this.reqs.values()].find(
      (r) =>
        ((r.from === from && r.to === to) || (r.from === to && r.to === from)) && r.status === 'pending',
    );
    if (pending) throw new BadRequestException({ code: 'ALREADY_PENDING', message: 'request already pending' });
    const cd = this.declineCooldown.get(`${from}:${to}`) ?? 0;
    if (Date.now() - cd < DECLINE_COOLDOWN_MS) {
      const h = Math.ceil((DECLINE_COOLDOWN_MS - (Date.now() - cd)) / 3600_000);
      throw new BadRequestException({ code: 'DECLINE_COOLDOWN', message: `cooldown after decline: ~${h}h left` });
    }
    const r: FriendRequest = {
      id: randomUUID(),
      from,
      to,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };
    this.reqs.set(r.id, r);
    return r;
  }

  accept(id: string, actorId?: string): Friendship {
    const r = this.reqs.get(id);
    if (!r) throw new NotFoundException({ code: 'NOT_FOUND', message: 'request not found' });
    if (r.status !== 'pending') throw new BadRequestException({ code: 'BAD_REQUEST', message: 'request not pending' });
    if (actorId && r.to !== actorId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'only recipient can accept' });
    }
    if (this.isBlocked(r.from, r.to)) {
      throw new ForbiddenException({ code: 'BLOCKED', message: 'action forbidden by block' });
    }
    r.status = 'accepted';
    const f: Friendship = {
      id: randomUUID(),
      userA: r.from,
      userB: r.to,
      createdAt: new Date().toISOString(),
      manualOrder: Date.now(),
    };
    this.friendships.set(pairKey(r.from, r.to), f);
    this.touchActivity(r.from, r.to);
    this.touchActivity(r.to, r.from);
    return f;
  }

  decline(id: string, actorId?: string): FriendRequest {
    const r = this.reqs.get(id);
    if (!r) throw new NotFoundException({ code: 'NOT_FOUND', message: 'request not found' });
    if (r.status !== 'pending') throw new BadRequestException({ code: 'BAD_REQUEST', message: 'request not pending' });
    if (actorId && r.to !== actorId && r.from !== actorId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'not a party of request' });
    }
    r.status = 'declined';
    // Cooldown 24ч на повторную заявку from->to после decline.
    this.declineCooldown.set(`${r.from}:${r.to}`, Date.now());
    return r;
  }

  listRequests(
    userId: string,
    opts: { cursor?: string; limit?: number; box?: 'inbox' | 'outbox' | 'all' } = {},
  ) {
    let arr = [...this.reqs.values()].filter((r) => {
      if (opts.box === 'inbox') return r.to === userId;
      if (opts.box === 'outbox') return r.from === userId;
      return r.from === userId || r.to === userId;
    });
    arr.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
    return paginateCursor(arr, opts.cursor, opts.limit ?? 20, (r) => r.id);
  }

  // ---- дружба ----

  areFriends(a: string, b: string): boolean {
    return this.friendships.has(pairKey(a, b));
  }

  getFriendship(a: string, b: string): Friendship | null {
    return this.friendships.get(pairKey(a, b)) ?? null;
  }

  removeFriend(a: string, b: string): { removed: boolean } {
    const ok = this.friendships.delete(pairKey(a, b));
    return { removed: ok };
  }

  listFriends(
    userId: string,
    opts: { cursor?: string; limit?: number; sort?: FriendSort; q?: string } = {},
  ) {
    const sort = opts.sort ?? 'manual';
    const views: FriendView[] = [];
    for (const f of this.friendships.values()) {
      const other = f.userA === userId ? f.userB : f.userA === userId ? null : null;
      const friendId = f.userA === userId ? f.userB : f.userB === userId ? f.userA : null;
      if (!friendId) continue;
      void other;
      const dir = this.directory.get(friendId);
      const name = dir?.username ?? friendId;
      if (opts.q && !name.toLowerCase().includes(opts.q.toLowerCase())) continue;
      views.push({
        userId: friendId,
        username: name,
        friendSince: f.createdAt,
        favorite: this.favorites.get(userId)?.has(friendId) ?? false,
        pinned: this.pins.get(userId)?.has(friendId) ?? false,
        muted: this.mutes.get(userId)?.has(friendId) ?? false,
        lastSeenAt: this.lastSeen.has(friendId) ? new Date(this.lastSeen.get(friendId)!).toISOString() : null,
        interactions: this.interactions.get(userId)?.get(friendId) ?? 0,
      });
    }
    const byName = (a: FriendView, b: FriendView) => a.username.localeCompare(b.username);
    switch (sort) {
      case 'name':
        views.sort(byName);
        break;
      case 'lastSeen':
        views.sort((a, b) => (b.lastSeenAt ?? '').localeCompare(a.lastSeenAt ?? ''));
        break;
      case 'frequency':
        views.sort((a, b) => b.interactions - a.interactions || byName(a, b));
        break;
      case 'activity':
        views.sort((a, b) => b.interactions - a.interactions || (b.lastSeenAt ?? '').localeCompare(a.lastSeenAt ?? ''));
        break;
      case 'pinned':
        views.sort((a, b) => Number(b.pinned) - Number(a.pinned) || Number(b.favorite) - Number(a.favorite) || byName(a, b));
        break;
      case 'manual':
      default: {
        const order = new Map<string, number>();
        for (const f of this.friendships.values()) {
          const fid = f.userA === userId ? f.userB : f.userB === userId ? f.userA : null;
          if (fid) order.set(fid, f.manualOrder);
        }
        views.sort((a, b) => (order.get(a.userId) ?? 0) - (order.get(b.userId) ?? 0) || byName(a, b));
        break;
      }
    }
    // pinned всегда всплывают вверх, кроме явной ручной сортировки
    if (sort !== 'manual' && sort !== 'pinned') {
      views.sort((a, b) => Number(b.pinned) - Number(a.pinned));
    }
    return paginateCursor(views, opts.cursor, opts.limit ?? 20, (v) => v.userId);
  }

  reorder(userId: string, orderedIds: string[]): { ok: boolean } {
    const base = Date.now();
    orderedIds.forEach((fid, i) => {
      const f = this.friendships.get(pairKey(userId, fid));
      if (f) f.manualOrder = base + i;
    });
    return { ok: true };
  }

  private flag(map: Map<string, Set<string>>, userId: string, friendId: string, value: boolean): { ok: boolean } {
    if (!this.areFriends(userId, friendId)) {
      throw new BadRequestException({ code: 'NOT_FRIENDS', message: 'not friends' });
    }
    let set = map.get(userId);
    if (!set) {
      set = new Set();
      map.set(userId, set);
    }
    if (value) set.add(friendId);
    else set.delete(friendId);
    return { ok: true };
  }

  setFavorite(userId: string, friendId: string, value: boolean) {
    return this.flag(this.favorites, userId, friendId, value);
  }

  setPinned(userId: string, friendId: string, value: boolean) {
    return this.flag(this.pins, userId, friendId, value);
  }

  setMuted(userId: string, friendId: string, value: boolean) {
    return this.flag(this.mutes, userId, friendId, value);
  }

  // ---- поиск и QR ----

  searchByUsername(q: string, limit = 20) {
    const needle = q.trim().replace(/^@/, '').toLowerCase();
    if (!needle) return [];
    return [...this.directory.values()]
      .filter((u) => u.username.toLowerCase().includes(needle))
      .slice(0, Math.min(100, Math.max(1, limit)));
  }

  qrPayload(userId: string): { userId: string; code: string } {
    let code = this.qrCodes.get(userId);
    if (!code) {
      code = randomUUID().replace(/-/g, '').slice(0, 8);
      this.qrCodes.set(userId, code);
    }
    return { userId, code };
  }

  qrResolve(code: string): { userId: string } | null {
    for (const [uid, c] of this.qrCodes) {
      if (c === code) return { userId: uid };
    }
    return null;
  }
}

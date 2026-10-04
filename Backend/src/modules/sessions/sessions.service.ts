import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { canTransition, SessionState } from '../../common/engines/session.engine';
import { paginateCursor } from '../../common/pagination';

export type ParticipantStatus =
  | 'pending'
  | 'invited'
  | 'accepted'
  | 'declined'
  | 'ready'
  | 'not-ready'
  | 'away'
  | 'left';

export interface SessionParticipant {
  userId: string;
  status: ParticipantStatus;
  joinedAt: string;
}

/** Спец-объект приглашения (НЕ текстовое сообщение): создаётся invite/accept/decline флоу. */
export interface SessionInvite {
  kind: 'session-invite';
  id: string;
  sessionId: string;
  from: string;
  to: string;
  status: 'pending' | 'accepted' | 'declined';
  createdAt: string;
}

export interface SessionBanner {
  x: number;
  y: number;
  startAt: string;
}

export interface GameSession {
  id: string;
  title: string;
  game: string;
  mode: string;
  slots: number; // 2..10
  scheduledAt: string | null;
  comment: string;
  creatorId: string;
  state: SessionState;
  participants: SessionParticipant[];
  invites: SessionInvite[];
  banner: SessionBanner | null;
  startedAt: string | null; // таймер: проставляется при входе в Live
  finishedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateSessionInput {
  title: string;
  game: string;
  mode?: string;
  slots?: number;
  scheduledAt?: string | null;
  comment?: string;
  creatorId: string;
  invites?: string[]; // userIds — каждому создаётся SessionInvite-объект
}

const TERMINAL: SessionState[] = ['Finished', 'Cancelled'];
const JOINABLE: SessionState[] = ['Inviting', 'Waiting', 'Ready', 'Live', 'Paused'];

// In-memory репозиторий с интерфейсом под замену на TypeORM.
// TODO(db): SQL — таблицы game_sessions + session_participants + session_invites (kind=session-invite, не текст).
@Injectable()
export class SessionsService {
  private sessions = new Map<string, GameSession>();
  private blocks = new Set<string>(); // "a:b" — блокировки для invite/join проверок

  // ---- блокировки (зеркало FriendsService для Tier1 без кросс-модульных импортов) ----

  setBlock(a: string, b: string): void {
    this.blocks.add(`${a}:${b}`);
  }

  isBlocked(a: string, b: string): boolean {
    return this.blocks.has(`${a}:${b}`) || this.blocks.has(`${b}:${a}`);
  }

  // ---- CRUD ----

  create(input: CreateSessionInput): GameSession {
    const title = (input.title ?? '').trim();
    if (!title || title.length > 120) {
      throw new BadRequestException({ code: 'INVALID_TITLE', message: 'title 1..120 chars' });
    }
    const game = (input.game ?? '').trim();
    if (!game) throw new BadRequestException({ code: 'INVALID_GAME', message: 'game required' });
    const slots = input.slots ?? 4;
    if (!Number.isInteger(slots) || slots < 2 || slots > 10) {
      throw new BadRequestException({ code: 'INVALID_SLOTS', message: 'slots must be 2..10' });
    }
    if (!input.creatorId) throw new BadRequestException({ code: 'BAD_REQUEST', message: 'creatorId required' });
    const now = new Date().toISOString();
    const s: GameSession = {
      id: randomUUID(),
      title,
      game,
      mode: (input.mode ?? 'Casual').trim() || 'Casual',
      slots,
      scheduledAt: input.scheduledAt ?? null,
      comment: (input.comment ?? '').slice(0, 500),
      creatorId: input.creatorId,
      state: 'Draft',
      participants: [{ userId: input.creatorId, status: 'ready', joinedAt: now }],
      invites: [],
      banner: null,
      startedAt: null,
      finishedAt: null,
      createdAt: now,
      updatedAt: now,
    };
    this.sessions.set(s.id, s);
    for (const to of input.invites ?? []) {
      if (to !== input.creatorId) this.invite(s.id, input.creatorId, to);
    }
    return s;
  }

  get(id: string): GameSession {
    const s = this.sessions.get(id);
    if (!s) throw new NotFoundException({ code: 'NOT_FOUND', message: 'session not found' });
    return s;
  }

  list(): GameSession[] {
    return [...this.sessions.values()];
  }

  listPaginated(opts: { cursor?: string; limit?: number } = {}) {
    const arr = [...this.sessions.values()].sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
    return paginateCursor(arr, opts.cursor, opts.limit ?? 20, (s) => s.id);
  }

  // ---- state machine ----

  transition(id: string, to: SessionState, actorId?: string): GameSession {
    const s = this.get(id);
    if (!canTransition(s.state, to)) {
      throw new BadRequestException({ code: 'INVALID_TRANSITION', message: `cannot ${s.state} -> ${to}` });
    }
    if ((to === 'Cancelled' || to === 'Finished') && actorId && actorId !== s.creatorId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'only creator can cancel/finish' });
    }
    s.state = to;
    s.updatedAt = new Date().toISOString();
    if (to === 'Live' && !s.startedAt) {
      // joining→Live запускает таймер сессии
      s.startedAt = new Date().toISOString();
      if (!s.banner) {
        s.banner = { x: 0, y: 0, startAt: s.startedAt };
      }
    }
    if (to === 'Finished' || to === 'Cancelled') s.finishedAt = new Date().toISOString();
    return s;
  }

  // ---- invites: спец-объект, не текст ----

  private activeCount(s: GameSession): number {
    return s.participants.filter((p) => p.status !== 'left' && p.status !== 'declined').length;
  }

  invite(id: string, from: string, to: string): SessionInvite {
    const s = this.get(id);
    if (TERMINAL.includes(s.state)) {
      throw new BadRequestException({ code: 'SESSION_CLOSED', message: `cannot invite in ${s.state}` });
    }
    if (this.isBlocked(from, to)) {
      throw new ForbiddenException({ code: 'BLOCKED', message: 'invite forbidden by block' });
    }
    if (this.activeCount(s) >= s.slots) {
      throw new BadRequestException({ code: 'SESSION_FULL', message: `session full (${s.slots} slots)` });
    }
    const existing = s.invites.find((i) => i.to === to && i.status === 'pending');
    if (existing) return existing;
    if (!s.participants.some((p) => p.userId === to)) {
      s.participants.push({ userId: to, status: 'invited', joinedAt: new Date().toISOString() });
    }
    const inv: SessionInvite = {
      kind: 'session-invite',
      id: randomUUID(),
      sessionId: s.id,
      from,
      to,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };
    s.invites.push(inv);
    s.updatedAt = new Date().toISOString();
    return inv;
  }

  respond(id: string, userId: string, accept: boolean): GameSession {
    const s = this.get(id);
    const inv = [...s.invites].reverse().find((i) => i.to === userId && i.status === 'pending');
    const p = s.participants.find((x) => x.userId === userId);
    if (!inv && !p) throw new NotFoundException({ code: 'NOT_FOUND', message: 'not invited' });
    if (inv) inv.status = accept ? 'accepted' : 'declined';
    if (p) p.status = accept ? 'accepted' : 'declined';
    else if (accept) s.participants.push({ userId, status: 'accepted', joinedAt: new Date().toISOString() });
    s.updatedAt = new Date().toISOString();
    return s;
  }

  join(id: string, userId: string): GameSession {
    const s = this.get(id);
    if (TERMINAL.includes(s.state)) {
      throw new BadRequestException({ code: 'SESSION_CLOSED', message: `cannot join in ${s.state}` });
    }
    if (!JOINABLE.includes(s.state)) {
      throw new BadRequestException({ code: 'NOT_JOINABLE', message: `cannot join in ${s.state}` });
    }
    if (this.isBlocked(s.creatorId, userId)) {
      throw new ForbiddenException({ code: 'BLOCKED', message: 'join forbidden by block' });
    }
    const existing = s.participants.find((p) => p.userId === userId);
    if (existing) {
      if (existing.status === 'left' || existing.status === 'declined') {
        if (this.activeCount(s) >= s.slots) {
          throw new BadRequestException({ code: 'SESSION_FULL', message: 'session full' });
        }
        existing.status = 'accepted';
      }
      return s;
    }
    if (this.activeCount(s) >= s.slots) {
      throw new BadRequestException({ code: 'SESSION_FULL', message: `session full (${s.slots} slots)` });
    }
    s.participants.push({ userId, status: 'accepted', joinedAt: new Date().toISOString() });
    s.updatedAt = new Date().toISOString();
    return s;
  }

  leave(id: string, userId: string): GameSession {
    const s = this.get(id);
    const p = s.participants.find((x) => x.userId === userId);
    if (!p) throw new NotFoundException({ code: 'NOT_FOUND', message: 'not a participant' });
    p.status = 'left';
    s.updatedAt = new Date().toISOString();
    return s;
  }

  setReady(id: string, userId: string, status: 'ready' | 'not-ready' | 'away'): GameSession {
    const s = this.get(id);
    if (TERMINAL.includes(s.state)) {
      throw new BadRequestException({ code: 'SESSION_CLOSED', message: `cannot set ready in ${s.state}` });
    }
    const p = s.participants.find((x) => x.userId === userId);
    if (!p) throw new NotFoundException({ code: 'NOT_FOUND', message: 'not a participant' });
    if (p.status === 'left' || p.status === 'declined') {
      throw new BadRequestException({ code: 'BAD_REQUEST', message: 'participant left session' });
    }
    p.status = status;
    s.updatedAt = new Date().toISOString();
    return s;
  }

  // ---- creator-only ----

  private assertCreator(s: GameSession, actorId: string): void {
    if (actorId !== s.creatorId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'only creator can do this' });
    }
  }

  edit(
    id: string,
    actorId: string,
    patch: { title?: string; comment?: string; scheduledAt?: string | null; slots?: number; mode?: string },
  ): GameSession {
    const s = this.get(id);
    this.assertCreator(s, actorId);
    if (TERMINAL.includes(s.state)) {
      throw new BadRequestException({ code: 'SESSION_CLOSED', message: `cannot edit in ${s.state}` });
    }
    if (patch.title !== undefined) {
      const t = patch.title.trim();
      if (!t || t.length > 120) throw new BadRequestException({ code: 'INVALID_TITLE', message: 'title 1..120' });
      s.title = t;
    }
    if (patch.comment !== undefined) s.comment = patch.comment.slice(0, 500);
    if (patch.scheduledAt !== undefined) s.scheduledAt = patch.scheduledAt;
    if (patch.mode !== undefined && patch.mode.trim()) s.mode = patch.mode.trim();
    if (patch.slots !== undefined) {
      if (!Number.isInteger(patch.slots) || patch.slots < 2 || patch.slots > 10) {
        throw new BadRequestException({ code: 'INVALID_SLOTS', message: 'slots must be 2..10' });
      }
      if (patch.slots < this.activeCount(s)) {
        throw new BadRequestException({ code: 'SLOTS_TOO_SMALL', message: 'slots below active participants' });
      }
      s.slots = patch.slots;
    }
    s.updatedAt = new Date().toISOString();
    return s;
  }

  kick(id: string, actorId: string, targetId: string): GameSession {
    const s = this.get(id);
    this.assertCreator(s, actorId);
    if (targetId === s.creatorId) {
      throw new BadRequestException({ code: 'BAD_REQUEST', message: 'cannot kick creator' });
    }
    const p = s.participants.find((x) => x.userId === targetId);
    if (!p) throw new NotFoundException({ code: 'NOT_FOUND', message: 'not a participant' });
    p.status = 'left';
    s.updatedAt = new Date().toISOString();
    return s;
  }

  retime(id: string, actorId: string, scheduledAt: string | null): GameSession {
    return this.edit(id, actorId, { scheduledAt });
  }

  cancel(id: string, actorId: string): GameSession {
    return this.transition(id, 'Cancelled', actorId);
  }

  finish(id: string, actorId?: string): GameSession {
    const s = this.get(id);
    // finish идёт по цепочке через допустимые переходы; прямой скачок запрещён engine.
    if (s.state === 'Live' || s.state === 'Paused') return this.transition(id, 'Finished', actorId);
    throw new BadRequestException({
      code: 'INVALID_TRANSITION',
      message: `finish allowed from Live/Paused, current ${s.state}`,
    });
  }

  setBanner(id: string, actorId: string, banner: { x: number; y: number; startAt: string }): GameSession {
    const s = this.get(id);
    this.assertCreator(s, actorId);
    if (typeof banner.x !== 'number' || typeof banner.y !== 'number' || !banner.startAt) {
      throw new BadRequestException({ code: 'INVALID_BANNER', message: 'banner needs x,y,startAt' });
    }
    s.banner = { x: banner.x, y: banner.y, startAt: banner.startAt };
    s.updatedAt = new Date().toISOString();
    return s;
  }

  remove(id: string, actorId?: string): { deleted: boolean } {
    const s = this.get(id);
    if (actorId) this.assertCreator(s, actorId);
    this.sessions.delete(id);
    return { deleted: true };
  }
}

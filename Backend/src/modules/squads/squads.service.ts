import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { canJoinSquad, hasRole, SquadRole } from '../../common/engines/permissions.engine';
import { levelForXp } from '../../common/engines/xp.engine';
import { updateStreak } from '../../common/engines/streak.engine';

export interface SquadMember {
  userId: string;
  role: SquadRole;
  joinedAt: string;
}

export interface SquadInvite {
  id: string;
  squadId: string;
  from: string;
  to: string;
  status: 'pending' | 'accepted' | 'declined';
  createdAt: string;
}

export interface Squad {
  id: string;
  name: string;
  avatar: string | null;
  ownerId: string;
  members: SquadMember[];
  chatId: string | null;
  xp: number;
  level: number;
  streak: number;
  lastActivityDate: string | null; // YYYY-MM-DD
  closed: boolean;
  createdAt: string;
  updatedAt: string;
}

export const SQUAD_MAX = 200;

// In-memory репозиторий с интерфейсом под замену на TypeORM.
// TODO(db): SQL — таблицы squads, squad_members (role check), squad_invites,
// squad_xp (xp/level/streak/last_activity_date); owner-guard — на уровне сервиса как здесь.
@Injectable()
export class SquadsService {
  private squads = new Map<string, Squad>();
  private invites = new Map<string, SquadInvite[]>(); // squadId -> invites

  create(name: string, ownerId: string, opts: { avatar?: string | null; chatId?: string | null } = {}): Squad {
    const clean = (name ?? '').trim();
    if (!clean || clean.length > 64) {
      throw new BadRequestException({ code: 'INVALID_NAME', message: 'squad name 1..64 chars' });
    }
    if (!ownerId) throw new BadRequestException({ code: 'BAD_REQUEST', message: 'ownerId required' });
    const now = new Date().toISOString();
    const s: Squad = {
      id: randomUUID(),
      name: clean,
      avatar: opts.avatar ?? null,
      ownerId,
      members: [{ userId: ownerId, role: 'Owner', joinedAt: now }],
      chatId: opts.chatId ?? null,
      xp: 0,
      level: 1,
      streak: 0,
      lastActivityDate: null,
      closed: false,
      createdAt: now,
      updatedAt: now,
    };
    this.squads.set(s.id, s);
    return s;
  }

  get(id: string): Squad {
    const s = this.squads.get(id);
    if (!s || s.closed) throw new NotFoundException({ code: 'NOT_FOUND', message: 'squad not found' });
    return s;
  }

  list(): Squad[] {
    return [...this.squads.values()].filter((s) => !s.closed);
  }

  private roleOf(s: Squad, userId: string): SquadMember | null {
    return s.members.find((m) => m.userId === userId) ?? null;
  }

  private assertOwner(s: Squad, actorId: string): SquadMember {
    const m = this.roleOf(s, actorId);
    if (!m || m.role !== 'Owner') {
      throw new ForbiddenException({ code: 'OWNER_ONLY', message: 'only squad owner can do this' });
    }
    return m;
  }

  private assertMember(s: Squad, actorId: string, min: SquadRole = 'Member'): SquadMember {
    const m = this.roleOf(s, actorId);
    if (!m || !hasRole(m.role, min)) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'squad membership required' });
    }
    return m;
  }

  // ---- owner-only: rename/avatar/chatId/remove/assign/close ----

  rename(id: string, actorId: string, name: string): Squad {
    const s = this.get(id);
    this.assertOwner(s, actorId);
    const clean = (name ?? '').trim();
    if (!clean || clean.length > 64) {
      throw new BadRequestException({ code: 'INVALID_NAME', message: 'squad name 1..64 chars' });
    }
    s.name = clean;
    s.updatedAt = new Date().toISOString();
    return s;
  }

  setAvatar(id: string, actorId: string, avatar: string | null): Squad {
    const s = this.get(id);
    this.assertOwner(s, actorId);
    s.avatar = avatar;
    s.updatedAt = new Date().toISOString();
    return s;
  }

  setChatId(id: string, actorId: string, chatId: string | null): Squad {
    const s = this.get(id);
    this.assertOwner(s, actorId);
    s.chatId = chatId;
    s.updatedAt = new Date().toISOString();
    return s;
  }

  assignRole(id: string, actorId: string, targetId: string, role: SquadRole): Squad {
    const s = this.get(id);
    this.assertOwner(s, actorId);
    if (!['Owner', 'Admin', 'Member'].includes(role)) {
      throw new BadRequestException({ code: 'INVALID_ROLE', message: 'role must be Owner|Admin|Member' });
    }
    const t = this.roleOf(s, targetId);
    if (!t) throw new NotFoundException({ code: 'NOT_FOUND', message: 'target not a member' });
    if (role === 'Owner') {
      // Передача владения: старый owner становится Admin.
      const me = this.roleOf(s, actorId)!;
      me.role = 'Admin';
      t.role = 'Owner';
      s.ownerId = targetId;
    } else {
      if (t.role === 'Owner') {
        throw new BadRequestException({ code: 'BAD_REQUEST', message: 'cannot demote owner, transfer first' });
      }
      t.role = role;
    }
    s.updatedAt = new Date().toISOString();
    return s;
  }

  addMember(id: string, userId: string, role: SquadRole = 'Member'): Squad {
    const s = this.get(id);
    if (!canJoinSquad(s.members.length, SQUAD_MAX)) {
      throw new BadRequestException({ code: 'SQUAD_FULL', message: 'squad full (200 max)' });
    }
    if (s.members.some((m) => m.userId === userId)) return s;
    if (role === 'Owner') {
      throw new BadRequestException({ code: 'INVALID_ROLE', message: 'use transfer to assign Owner' });
    }
    s.members.push({ userId, role, joinedAt: new Date().toISOString() });
    s.updatedAt = new Date().toISOString();
    return s;
  }

  removeMember(id: string, actorId: string, targetId: string): Squad {
    const s = this.get(id);
    this.assertOwner(s, actorId);
    if (targetId === s.ownerId) {
      throw new BadRequestException({ code: 'BAD_REQUEST', message: 'owner cannot be removed, transfer first' });
    }
    s.members = s.members.filter((m) => m.userId !== targetId);
    s.updatedAt = new Date().toISOString();
    return s;
  }

  /** Добровольный выход (не owner; owner — только через transfer/close). */
  leave(id: string, userId: string): Squad {
    const s = this.get(id);
    if (userId === s.ownerId && s.members.length > 1) {
      throw new BadRequestException({ code: 'OWNER_MUST_TRANSFER', message: 'owner must transfer ownership first' });
    }
    s.members = s.members.filter((m) => m.userId !== userId);
    if (s.members.length === 0) s.closed = true;
    s.updatedAt = new Date().toISOString();
    return s;
  }

  close(id: string, actorId: string): { closed: boolean } {
    const s = this.get(id);
    this.assertOwner(s, actorId);
    s.closed = true;
    s.updatedAt = new Date().toISOString();
    return { closed: true };
  }

  // ---- invite-all: создаёт invites всем selected ----

  inviteAll(id: string, actorId: string, userIds: string[]): SquadInvite[] {
    const s = this.get(id);
    this.assertMember(s, actorId);
    const arr = this.invites.get(id) ?? [];
    const created: SquadInvite[] = [];
    for (const to of new Set(userIds)) {
      if (s.members.some((m) => m.userId === to)) continue;
      if (arr.some((i) => i.to === to && i.status === 'pending')) continue;
      const inv: SquadInvite = {
        id: randomUUID(),
        squadId: id,
        from: actorId,
        to,
        status: 'pending',
        createdAt: new Date().toISOString(),
      };
      arr.push(inv);
      created.push(inv);
    }
    this.invites.set(id, arr);
    return created;
  }

  listInvites(id: string): SquadInvite[] {
    this.get(id);
    return this.invites.get(id) ?? [];
  }

  respondInvite(id: string, inviteId: string, accept: boolean): Squad {
    const s = this.get(id);
    const arr = this.invites.get(id) ?? [];
    const inv = arr.find((i) => i.id === inviteId);
    if (!inv || inv.status !== 'pending') {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'invite not found' });
    }
    inv.status = accept ? 'accepted' : 'declined';
    if (accept) this.addMember(id, inv.to, 'Member');
    return s;
  }

  // ---- XP/Level/Streak: поля + endpoint активности ----
  // Логику начисления ведёт другой агент; здесь минимальное обновление полей.

  recordActivity(
    id: string,
    opts: { xpDelta?: number; playedDate?: string; won?: boolean } = {},
  ): Pick<Squad, 'id' | 'xp' | 'level' | 'streak' | 'lastActivityDate'> {
    const s = this.get(id);
    const delta = Math.floor(opts.xpDelta ?? 0);
    if (delta !== 0) s.xp = Math.max(0, s.xp + delta);
    s.level = levelForXp(s.xp);
    const today = opts.playedDate ?? new Date().toISOString().slice(0, 10);
    const r = updateStreak(s.lastActivityDate, today, s.streak);
    s.streak = r.streak;
    s.lastActivityDate = today;
    void opts.won;
    s.updatedAt = new Date().toISOString();
    return { id: s.id, xp: s.xp, level: s.level, streak: s.streak, lastActivityDate: s.lastActivityDate };
  }
}

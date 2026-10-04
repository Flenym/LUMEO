import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';

// 15 типов уведомлений из ТЗ.
export type NotificationType =
  | 'friend.request'
  | 'friend.accept'
  | 'friend.available'
  | 'session.invite'
  | 'session.start'
  | 'session.reminder'
  | 'squad.invite'
  | 'squad.update'
  | 'gift.received'
  | 'achievement'
  | 'streak.reminder'
  | 'status.digest'
  | 'workshop.update'
  | 'moderation'
  | 'system';

export const NOTIFICATION_TYPES: NotificationType[] = [
  'friend.request',
  'friend.accept',
  'friend.available',
  'session.invite',
  'session.start',
  'session.reminder',
  'squad.invite',
  'squad.update',
  'gift.received',
  'achievement',
  'streak.reminder',
  'status.digest',
  'workshop.update',
  'moderation',
  'system',
];

export type NotificationStatus = 'sent' | 'delayed' | 'digested' | 'dropped';

export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  payload: Record<string, unknown>;
  status: NotificationStatus;
  read: boolean;
  createdAt: string;
}

export interface QuietHours {
  /** Час начала (0-23, локальное время юзера). */
  start: number;
  /** Час конца (0-23). */
  end: number;
}

export interface UserNotifPrefs {
  quietHours?: QuietHours;
  mutedChats: string[];
  mutedUsers: string[];
  favorites: string[];
  /** digest по статусам: throttle 1/час на друга (храним lastStatusDigestAt). */
  lastStatusDigestAt: Record<string, number>;
}

const STATUS_DIGEST_THROTTLE_MS = 3600_000;

// TODO: PostgreSQL Notification + APNs отправка (заглушка — только in-memory).
@Injectable()
export class NotificationsService {
  private items: Notification[] = [];
  private prefs = new Map<string, UserNotifPrefs>();

  private getPrefs(userId: string): UserNotifPrefs {
    let p = this.prefs.get(userId);
    if (!p) {
      p = { mutedChats: [], mutedUsers: [], favorites: [], lastStatusDigestAt: {} };
      this.prefs.set(userId, p);
    }
    return p;
  }

  setPrefs(userId: string, patch: Partial<{ quietHours: QuietHours; mutedChats: string[]; mutedUsers: string[]; favorites: string[] }>) {
    const p = this.getPrefs(userId);
    if (patch.quietHours !== undefined) {
      const { start, end } = patch.quietHours;
      if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0 || start > 23 || end < 0 || end > 23) {
        throw new BadRequestException('quietHours start/end must be integers 0..23');
      }
      p.quietHours = { start, end };
    }
    if (patch.mutedChats !== undefined) p.mutedChats = [...patch.mutedChats];
    if (patch.mutedUsers !== undefined) p.mutedUsers = [...patch.mutedUsers];
    if (patch.favorites !== undefined) p.favorites = [...patch.favorites];
    return { userId, ...p };
  }

  getPrefsView(userId: string) {
    return { userId, ...this.getPrefs(userId) };
  }

  private inQuietHours(p: UserNotifPrefs, nowHour: number): boolean {
    const q = p.quietHours;
    if (!q) return false;
    if (q.start <= q.end) return nowHour >= q.start && nowHour < q.end;
    return nowHour >= q.start || nowHour < q.end; // через полночь
  }

  /**
   * Внутренняя отправка (POST /notifications/send).
   * Правила:
   * - per-chat/per-user mute -> dropped;
   * - quiet-hours -> delayed;
   * - friend.available -> только favorites (иначе dropped);
   * - статусы друзей -> digest с throttle 1/ч на друга (digested).
   */
  send(
    userId: string,
    type: NotificationType,
    payload: Record<string, unknown> = {},
    opts: { nowHour?: number; nowMs?: number } = {},
  ): Notification {
    if (!NOTIFICATION_TYPES.includes(type)) throw new BadRequestException(`unknown notification type: ${type}`);
    const p = this.getPrefs(userId);
    const chatId = typeof payload.chatId === 'string' ? payload.chatId : undefined;
    const fromUser = typeof payload.fromUserId === 'string' ? payload.fromUserId : undefined;

    let status: NotificationStatus = 'sent';
    if ((chatId && p.mutedChats.includes(chatId)) || (fromUser && p.mutedUsers.includes(fromUser))) {
      status = 'dropped';
    } else if (type === 'friend.available') {
      // «Notify when friend becomes available» — только избранные.
      if (!fromUser || !p.favorites.includes(fromUser)) status = 'dropped';
    } else if (type === 'status.digest' && fromUser) {
      const now = opts.nowMs ?? Date.now();
      const last = p.lastStatusDigestAt[fromUser] ?? 0;
      if (now - last < STATUS_DIGEST_THROTTLE_MS) {
        status = 'digested';
      } else {
        p.lastStatusDigestAt[fromUser] = now;
      }
    }
    if (status === 'sent' && this.inQuietHours(p, opts.nowHour ?? new Date().getHours())) {
      status = 'delayed';
    }
    const n: Notification = {
      id: randomUUID(),
      userId,
      type,
      payload,
      status,
      read: false,
      createdAt: new Date(opts.nowMs ?? Date.now()).toISOString(),
    };
    this.items.push(n);
    return n;
  }

  /** GET mine с фильтрами type/read/status. */
  mine(userId: string, filter: { type?: NotificationType; read?: boolean; status?: NotificationStatus } = {}) {
    return this.items.filter(
      (n) =>
        n.userId === userId &&
        (filter.type === undefined || n.type === filter.type) &&
        (filter.read === undefined || n.read === filter.read) &&
        (filter.status === undefined || n.status === filter.status),
    );
  }

  markRead(userId: string, id: string) {
    const n = this.items.find((x) => x.userId === userId && x.id === id);
    if (!n) return { notFound: true };
    n.read = true;
    return n;
  }

  /** Доставка для аналитики (доля sent от всех нетронутых mute). */
  deliveryStats() {
    const total = this.items.length;
    const byStatus: Record<string, number> = {};
    for (const n of this.items) byStatus[n.status] = (byStatus[n.status] ?? 0) + 1;
    return { total, byStatus };
  }
}

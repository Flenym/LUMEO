import { Injectable } from '@nestjs/common';
import { xpForEvent, levelForXp, rankForLevel, rankDivision, rankDisplay } from '../../common/engines/xp.engine';

/** Дневной лимит XP из фармируемых событий (анти-фарм, счётчик в памяти). */
export const DAILY_XP_CAP = 200;

/** События, на которые НЕ действует дневной кап (разовые/проверяемые). */
const UNCAPPED_EVENTS = new Set(['achievement', 'session_complete']);

export interface AchievementDef {
  code: string;
  title: string;
  xp: number;
}

/** Каталог достижений (6 шт, сид также в migrations/003_seed.sql). */
export const ACHIEVEMENTS: AchievementDef[] = [
  { code: 'first-session', title: 'First Session', xp: 30 },
  { code: 'streak-7', title: '7-Day Streak', xp: 30 },
  { code: 'social-5', title: 'Social Butterfly (5 friends)', xp: 30 },
  { code: 'creator', title: 'Workshop Creator', xp: 30 },
  { code: 'squad-founder', title: 'Squad Founder', xp: 30 },
  { code: 'level-10', title: 'Level 10', xp: 30 },
];

export interface AddXpResult {
  userId: string;
  event: string;
  base: number;
  awarded: number;
  capped: boolean;
  totalXp: number;
  level: number;
  rank: string;
  leveledUp: boolean;
  achievements: string[];
}

@Injectable()
export class LevelsService {
  private xp = new Map<string, number>();
  private daily = new Map<string, { day: string; total: number }>();
  private eventCounts = new Map<string, Map<string, number>>();
  private achievements = new Map<string, Set<string>>();

  private dayKey(userId: string, day: string): string {
    return `${userId}:${day}`;
  }

  private countEvent(userId: string, event: string): number {
    let m = this.eventCounts.get(userId);
    if (!m) {
      m = new Map();
      this.eventCounts.set(userId, m);
    }
    const next = (m.get(event) ?? 0) + 1;
    m.set(event, next);
    return next;
  }

  private grantAchievement(userId: string, code: string): boolean {
    let set = this.achievements.get(userId);
    if (!set) {
      set = new Set();
      this.achievements.set(userId, set);
    }
    if (set.has(code)) return false;
    set.add(code);
    return true;
  }

  private autoCheck(userId: string, level: number): string[] {
    const counts = this.eventCounts.get(userId);
    const n = (e: string) => counts?.get(e) ?? 0;
    const awarded: string[] = [];
    const give = (code: string) => {
      if (this.grantAchievement(userId, code)) awarded.push(code);
    };
    if (n('session_complete') >= 1) give('first-session');
    if (n('streak_day') >= 7) give('streak-7');
    if (n('friend_add') >= 5) give('social-5');
    if (n('workshop_publish') >= 1) give('creator');
    if (n('squad_create') >= 1) give('squad-founder');
    if (level >= 10) give('level-10');
    return awarded;
  }

  /**
   * Начисление XP за событие с анти-фармом: не более DAILY_XP_CAP XP в сутки
   * (UTC-день) из фармируемых событий. achievement/session_complete — без капа.
   */
  addXp(userId: string, event: string, day?: string): AddXpResult {
    const base = xpForEvent(event);
    const today = day ?? new Date().toISOString().slice(0, 10);
    const before = this.xp.get(userId) ?? 0;
    const beforeLevel = levelForXp(before);
    if (base <= 0) {
      return {
        userId,
        event,
        base,
        awarded: 0,
        capped: false,
        totalXp: before,
        level: beforeLevel,
        rank: rankDisplay(beforeLevel),
        leveledUp: false,
        achievements: [],
      };
    }
    let awarded = base;
    let capped = false;
    if (!UNCAPPED_EVENTS.has(event)) {
      const key = this.dayKey(userId, today);
      const entry = this.daily.get(key) ?? { day: today, total: 0 };
      const room = DAILY_XP_CAP - entry.total;
      if (room <= 0) {
        awarded = 0;
        capped = true;
      } else if (awarded > room) {
        awarded = room;
        capped = true;
      }
      entry.total += awarded;
      this.daily.set(key, entry);
    }
    const total = before + awarded;
    this.xp.set(userId, total);
    const level = levelForXp(total);
    if (awarded > 0) this.countEvent(userId, event);
    // XP за саму ачивку начисляется напрямую (без рекурсии и без капа).
    const fresh = awarded > 0 ? this.autoCheck(userId, level) : [];
    let bonus = 0;
    for (const code of fresh) {
      const def = ACHIEVEMENTS.find((a) => a.code === code);
      if (def) bonus += def.xp;
    }
    const finalTotal = total + bonus;
    if (bonus > 0) this.xp.set(userId, finalTotal);
    const finalLevel = levelForXp(finalTotal);
    return {
      userId,
      event,
      base,
      awarded: awarded + bonus,
      capped,
      totalXp: finalTotal,
      level: finalLevel,
      rank: rankDisplay(finalLevel),
      leveledUp: finalLevel > beforeLevel,
      achievements: fresh,
    };
  }

  getProgress(userId: string) {
    const totalXp = this.xp.get(userId) ?? 0;
    const level = levelForXp(totalXp);
    return {
      userId,
      totalXp,
      level,
      rank: rankForLevel(level),
      division: rankDivision(level),
      display: rankDisplay(level),
      achievements: [...(this.achievements.get(userId) ?? [])],
    };
  }

  /** Выдача ачивки напрямую (используется admin/tests). Возвращает true если новая. */
  awardAchievement(userId: string, code: string): boolean {
    if (!ACHIEVEMENTS.some((a) => a.code === code)) throw new Error(`unknown achievement: ${code}`);
    return this.grantAchievement(userId, code);
  }

  /** Прямой грант XP от админа (без капа, с аудитом на стороне admin API). */
  grantXp(userId: string, amount: number) {
    if (!Number.isInteger(amount) || amount <= 0) throw new Error('grant amount must be positive integer');
    const before = this.xp.get(userId) ?? 0;
    const total = before + amount;
    this.xp.set(userId, total);
    return { userId, before, totalXp: total, level: levelForXp(total), display: rankDisplay(levelForXp(total)) };
  }

  /** Revoke XP (пол вниз 0). */
  revokeXp(userId: string, amount: number) {
    if (!Number.isInteger(amount) || amount <= 0) throw new Error('revoke amount must be positive integer');
    const before = this.xp.get(userId) ?? 0;
    const total = Math.max(0, before - amount);
    this.xp.set(userId, total);
    return { userId, before, totalXp: total, level: levelForXp(total), display: rankDisplay(levelForXp(total)) };
  }
}

import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { isPublicTextAllowed } from '../../common/engines/moderation';
import { updateStreak, squadDayActivity, todayStr } from '../../common/engines/streak.engine';
import { LevelsService } from './levels.service';

/** Официальные темы (8) из Design/theme.json + custom. */
export const OFFICIAL_THEMES = [
  { id: 'oled-orange', name: 'OLED Orange', accent: '#FF6B00', builtin: true },
  { id: 'purple', name: 'Purple', accent: '#AF52DE', builtin: true },
  { id: 'blue', name: 'Blue', accent: '#0A84FF', builtin: true },
  { id: 'cyan', name: 'Cyan', accent: '#64D2FF', builtin: true },
  { id: 'green', name: 'Green', accent: '#30D158', builtin: true },
  { id: 'yellow', name: 'Yellow', accent: '#FFD60A', builtin: true },
  { id: 'red', name: 'Red', accent: '#FF453A', builtin: true },
  { id: 'pink', name: 'Pink', accent: '#FF375F', builtin: true },
] as const;

export type OfficialThemeId = (typeof OFFICIAL_THEMES)[number]['id'];

export function isOfficialTheme(id: string): boolean {
  return OFFICIAL_THEMES.some((t) => t.id === id);
}

/** Системные блоки: удалить нельзя (ошибка SYSTEM_BLOCK). */
export const SYSTEM_BLOCKS = ['identity', 'friend-action', 'safety'];

export type BlockVisibility = 'public' | 'friends' | 'private';

export interface BlockPosition {
  x: number;
  y: number;
}

export interface ProfileBlock {
  id: string;
  type: string;
  position: BlockPosition;
  width: number; // 1..12 grid
  height: number; // 1..20
  visibility: BlockVisibility;
  theme?: string;
  critical?: boolean;
  data: Record<string, unknown>;
}

const GRID_COLS = 12;
const MIN_W = 1;
const MAX_W = 12;
const MIN_H = 1;
const MAX_H = 20;

function rectsOverlap(a: ProfileBlock, b: ProfileBlock): boolean {
  return (
    a.position.x < b.position.x + b.width &&
    b.position.x < a.position.x + a.width &&
    a.position.y < b.position.y + b.height &&
    b.position.y < a.position.y + a.height
  );
}

function validateBlockInput(input: {
  type: string;
  position: BlockPosition;
  width: number;
  height: number;
  visibility: BlockVisibility;
}): void {
  if (!input.type || typeof input.type !== 'string') throw new BadRequestException('block type required');
  const { x, y } = input.position ?? ({} as BlockPosition);
  if (!Number.isInteger(x) || !Number.isInteger(y) || x < 0 || y < 0) {
    throw new BadRequestException('position must be non-negative integers {x,y}');
  }
  if (!Number.isInteger(input.width) || input.width < MIN_W || input.width > MAX_W) {
    throw new BadRequestException(`width must be integer ${MIN_W}..${MAX_W} (grid)`);
  }
  if (!Number.isInteger(input.height) || input.height < MIN_H || input.height > MAX_H) {
    throw new BadRequestException(`height must be integer ${MIN_H}..${MAX_H}`);
  }
  if (x + input.width > GRID_COLS) {
    throw new BadRequestException(`block overflows grid: x + width must be <= ${GRID_COLS}`);
  }
  if (!['public', 'friends', 'private'].includes(input.visibility)) {
    throw new BadRequestException('visibility must be public|friends|private');
  }
}

/** Категории бейджей (7 шт). Sponsor — с градиент-флагом. */
export const BADGE_CATEGORIES = [
  'founder',
  'season',
  'skill',
  'social',
  'creator',
  'sponsor',
  'event',
] as const;

export type BadgeCategory = (typeof BADGE_CATEGORIES)[number];

export interface Badge {
  code: string;
  title: string;
  category: BadgeCategory;
  /** Sponsor-бейджи несут градиент. */
  gradient: boolean;
}

export type VerificationKind = 'Verified' | 'Official' | 'Sponsor' | 'BetaTester';
export type VerificationStatus = 'pending' | 'approved' | 'rejected';

export interface VerificationRequest {
  id: string;
  userId: string;
  kind: VerificationKind;
  status: VerificationStatus;
  createdAt: string;
  decidedAt?: string;
  reason?: string;
}

export interface FeedbackVote {
  fromUserId: string;
  targetId: string;
  kind: 'good' | 'bad';
  at: string;
}

// TODO: PostgreSQL Profile + ProfileBlock + ProfileTheme.
@Injectable()
export class ProfilesService {
  private profiles = new Map<string, { bio: string; theme: string; customTheme?: unknown; updatedAt: string }>();
  private blocks = new Map<string, ProfileBlock[]>(); // userId -> blocks
  private badges = new Map<string, Badge[]>(); // userId -> badges
  private verification = new Map<string, VerificationRequest[]>(); // userId -> requests
  private feedback: FeedbackVote[] = [];
  /** Пары с общей активностью (session/squad): "a|b" (отсортировано). */
  private sharedPairs = new Set<string>();
  private streaks = new Map<string, { streak: number; lastDay: string | null }>();
  private banned = ['spam-word-1'];

  constructor(private readonly levels: LevelsService) {}

  // ---------- Profile ----------

  upsert(userId: string, bio: string, theme = 'default') {
    const check = isPublicTextAllowed(bio || '', this.banned);
    if (bio && !check.allowed) return { allowed: false as const, reason: check.reason };
    if (theme !== 'default' && !isOfficialTheme(theme)) {
      throw new BadRequestException(`unknown theme: ${theme} (official or custom: required)`);
    }
    const p = { bio: bio ?? '', theme, updatedAt: new Date().toISOString() };
    this.profiles.set(userId, p);
    return { userId, ...p };
  }

  get(userId: string) {
    const base = this.profiles.get(userId) ?? { bio: '', theme: 'default', updatedAt: null };
    return { userId, ...base, progress: this.levels.getProgress(userId), streak: this.streaks.get(userId) ?? { streak: 0, lastDay: null } };
  }

  setTheme(userId: string, themeId: string, custom?: { name: string; accent: string }) {
    if (isOfficialTheme(themeId)) {
      const p = this.profiles.get(userId) ?? { bio: '', theme: 'default', updatedAt: new Date().toISOString() };
      const next = { ...p, theme: themeId, customTheme: undefined, updatedAt: new Date().toISOString() };
      this.profiles.set(userId, next);
      return { userId, theme: themeId, custom: false };
    }
    if (themeId === 'custom') {
      if (!custom || typeof custom.name !== 'string' || !/^#[0-9a-fA-F]{6}$/.test(custom.accent ?? '')) {
        throw new BadRequestException('custom theme requires {name, accent: #RRGGBB}');
      }
      const p = this.profiles.get(userId) ?? { bio: '', theme: 'default', updatedAt: new Date().toISOString() };
      const next = { ...p, theme: 'custom', customTheme: custom, updatedAt: new Date().toISOString() };
      this.profiles.set(userId, next);
      return { userId, theme: 'custom', custom: true, customTheme: custom };
    }
    throw new BadRequestException(`unknown theme: ${themeId}`);
  }

  officialThemes() {
    return [...OFFICIAL_THEMES];
  }

  // ---------- Blocks ----------

  listBlocks(userId: string): ProfileBlock[] {
    return [...(this.blocks.get(userId) ?? [])].sort((a, b) => a.position.y - b.position.y || a.position.x - b.position.x);
  }

  private assertNoCriticalOverlap(userId: string, candidate: ProfileBlock, ignoreId?: string): void {
    if (!candidate.critical) return;
    for (const b of this.blocks.get(userId) ?? []) {
      if (b.id === ignoreId || b.id === candidate.id) continue;
      if (rectsOverlap(candidate, b)) {
        throw new BadRequestException(`critical block overlaps block ${b.id} (no-overlap enforced server-side)`);
      }
    }
  }

  createBlock(
    userId: string,
    input: {
      type: string;
      position: BlockPosition;
      width: number;
      height: number;
      visibility: BlockVisibility;
      theme?: string;
      critical?: boolean;
      data?: Record<string, unknown>;
    },
  ): ProfileBlock {
    validateBlockInput(input);
    if (input.theme && input.theme !== 'default' && !isOfficialTheme(input.theme) && input.theme !== 'custom') {
      throw new BadRequestException(`unknown block theme: ${input.theme}`);
    }
    const block: ProfileBlock = {
      id: randomUUID(),
      type: input.type,
      position: { x: input.position.x, y: input.position.y },
      width: input.width,
      height: input.height,
      visibility: input.visibility,
      theme: input.theme,
      critical: input.critical ?? false,
      data: input.data ?? {},
    };
    this.assertNoCriticalOverlap(userId, block);
    const arr = this.blocks.get(userId) ?? [];
    arr.push(block);
    this.blocks.set(userId, arr);
    return block;
  }

  updateBlock(
    userId: string,
    blockId: string,
    patch: Partial<{ position: BlockPosition; width: number; height: number; visibility: BlockVisibility; theme: string; critical: boolean; data: Record<string, unknown> }>,
  ): ProfileBlock {
    const arr = this.blocks.get(userId) ?? [];
    const b = arr.find((x) => x.id === blockId);
    if (!b) throw new BadRequestException('block not found');
    const next: ProfileBlock = {
      ...b,
      position: patch.position ? { ...patch.position } : { ...b.position },
      width: patch.width ?? b.width,
      height: patch.height ?? b.height,
      visibility: patch.visibility ?? b.visibility,
      theme: patch.theme ?? b.theme,
      critical: patch.critical ?? b.critical,
      data: patch.data ?? b.data,
    };
    validateBlockInput(next);
    this.assertNoCriticalOverlap(userId, next, b.id);
    Object.assign(b, next);
    return b;
  }

  deleteBlock(userId: string, blockId: string) {
    const arr = this.blocks.get(userId) ?? [];
    const b = arr.find((x) => x.id === blockId);
    if (!b) throw new BadRequestException('block not found');
    if (SYSTEM_BLOCKS.includes(b.type)) {
      throw new ForbiddenException('SYSTEM_BLOCK: identity/friend-action/safety blocks cannot be deleted');
    }
    this.blocks.set(
      userId,
      arr.filter((x) => x.id !== blockId),
    );
    return { deleted: blockId };
  }

  /**
   * Reorder/snapping: серверная проверка — critical-блоки не должны
   * пересекаться после перемещения.
   */
  reorderBlocks(userId: string, order: { id: string; position: BlockPosition }[]) {
    const arr = this.blocks.get(userId) ?? [];
    const byId = new Map(arr.map((b) => [b.id, b]));
    for (const o of order) {
      const b = byId.get(o.id);
      if (!b) throw new BadRequestException(`block not found: ${o.id}`);
      if (!Number.isInteger(o.position?.x) || !Number.isInteger(o.position?.y) || o.position.x < 0 || o.position.y < 0) {
        throw new BadRequestException('position must be non-negative integers {x,y}');
      }
      if (o.position.x + b.width > GRID_COLS) {
        throw new BadRequestException(`block overflows grid: x + width must be <= ${GRID_COLS}`);
      }
    }
    // Применяем tentatively и проверяем critical-пересечения.
    const snapshot = arr.map((b) => ({ ...b, position: { ...b.position } }));
    for (const o of order) {
      const b = snapshot.find((x) => x.id === o.id);
      if (b) b.position = { x: o.position.x, y: o.position.y };
    }
    for (const c of snapshot) {
      if (!c.critical) continue;
      for (const o of snapshot) {
        if (o.id === c.id) continue;
        if (rectsOverlap(c, o)) {
          throw new BadRequestException(`critical block ${c.id} overlaps block ${o.id} after reorder`);
        }
      }
    }
    for (const o of order) {
      const real = byId.get(o.id);
      if (real) real.position = { x: o.position.x, y: o.position.y };
    }
    return this.listBlocks(userId);
  }

  // ---------- Badges (выдача ТОЛЬКО через admin) ----------

  listBadges(userId: string): Badge[] {
    return [...(this.badges.get(userId) ?? [])];
  }

  /**
   * Выдача бейджа. isAdmin=false (user endpoint) => 403.
   * Sponsor-бейджи помечаются gradient=true.
   */
  awardBadge(userId: string, badge: { code: string; title: string; category: BadgeCategory }, opts: { admin: boolean }) {
    if (!opts.admin) {
      throw new ForbiddenException('badges can only be awarded via admin API');
    }
    if (!BADGE_CATEGORIES.includes(badge.category)) {
      throw new BadRequestException(`unknown badge category (expected one of ${BADGE_CATEGORIES.join(',')})`);
    }
    const full: Badge = {
      code: badge.code,
      title: badge.title,
      category: badge.category,
      gradient: badge.category === 'sponsor',
    };
    const arr = this.badges.get(userId) ?? [];
    if (arr.some((b) => b.code === full.code)) return { ...full, duplicate: true };
    arr.push(full);
    this.badges.set(userId, arr);
    return { ...full, duplicate: false };
  }

  // ---------- Verification ----------

  requestVerification(userId: string, kind: VerificationKind): VerificationRequest {
    if (!['Verified', 'Official', 'Sponsor', 'BetaTester'].includes(kind)) {
      throw new BadRequestException('kind must be Verified|Official|Sponsor|BetaTester');
    }
    const req: VerificationRequest = {
      id: randomUUID(),
      userId,
      kind,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };
    const arr = this.verification.get(userId) ?? [];
    arr.push(req);
    this.verification.set(userId, arr);
    return req;
  }

  verificationStatus(userId: string) {
    return [...(this.verification.get(userId) ?? [])];
  }

  /** Все заявки верификации (для admin API). */
  allVerificationRequests(): VerificationRequest[] {
    return [...this.verification.values()].flat();
  }

  decideVerification(userId: string, requestId: string, approve: boolean, reason?: string, opts: { admin: boolean } = { admin: false }) {
    if (!opts.admin) throw new ForbiddenException('verification decisions are admin-only');
    const arr = this.verification.get(userId) ?? [];
    const r = arr.find((x) => x.id === requestId);
    if (!r) throw new BadRequestException('verification request not found');
    r.status = approve ? 'approved' : 'rejected';
    r.decidedAt = new Date().toISOString();
    if (reason) r.reason = reason;
    return r;
  }

  // ---------- Feedback (Good/Bad, анти-накрутка) ----------

  /** Регистрация общей активности (session/squad) между двумя юзерами. */
  registerSharedActivity(a: string, b: string) {
    const key = [a, b].sort().join('|');
    this.sharedPairs.add(key);
  }

  private pairKey(a: string, b: string): string {
    return [a, b].sort().join('|');
  }

  giveFeedback(fromUserId: string, targetId: string, kind: 'good' | 'bad') {
    if (fromUserId === targetId) throw new BadRequestException('cannot vote for yourself');
    if (kind !== 'good' && kind !== 'bad') throw new BadRequestException('kind must be good|bad');
    if (!this.sharedPairs.has(this.pairKey(fromUserId, targetId))) {
      throw new ForbiddenException('feedback requires a shared session or squad');
    }
    const now = Date.now();
    const recent = this.feedback.find(
      (v) => v.fromUserId === fromUserId && v.targetId === targetId && now - Date.parse(v.at) < 24 * 3600_000,
    );
    if (recent) throw new BadRequestException('only one vote per user-target pair per 24h');
    const vote: FeedbackVote = { fromUserId, targetId, kind, at: new Date(now).toISOString() };
    this.feedback.push(vote);
    return { ...vote, ...this.feedbackCounts(targetId) };
  }

  feedbackCounts(targetId: string) {
    const votes = this.feedback.filter((v) => v.targetId === targetId);
    return {
      targetId,
      good: votes.filter((v) => v.kind === 'good').length,
      bad: votes.filter((v) => v.kind === 'bad').length,
    };
  }

  // ---------- Streak ----------

  /**
   * Дневная активность: UTC-day diff через streak.engine, дубли в один день
   * игнорируются; squad-активность засчитывается только при sessionsJoinedCount>0.
   */
  recordStreakDay(userId: string, dateStr?: string, sessionsJoinedCount = 0) {
    const day = dateStr ?? todayStr();
    const state = this.streaks.get(userId) ?? { streak: 0, lastDay: null };
    if (state.lastDay === day) {
      return { userId, day, ...state, duplicate: true, squadActivity: squadDayActivity(sessionsJoinedCount) };
    }
    const res = updateStreak(state.lastDay, day, state.streak);
    const next = { streak: res.streak, lastDay: day };
    this.streaks.set(userId, next);
    const squadActivity = squadDayActivity(sessionsJoinedCount);
    // XP за streak-день — через levels (с анти-фармом).
    const xp = this.levels.addXp(userId, 'streak_day', day);
    return { userId, day, ...next, broken: res.broken, duplicate: false, squadActivity, xp };
  }
}

import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import * as os from 'os';
import * as fs from 'fs';
import { ProfilesService, BADGE_CATEGORIES, BadgeCategory } from '../profiles/profiles.service';
import { LevelsService, ACHIEVEMENTS } from '../profiles/levels.service';
import { WalletService } from '../wallet/wallet.service';
import { WorkshopService } from '../workshop/workshop.service';
import { ReportsService } from '../reports/reports.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AnalyticsService } from './analytics.service';
import { registerDevice } from './admin-devices';

export interface AuditEntry {
  admin: string;
  action: string;
  target: string;
  timestamp: string;
  reason?: string;
  old?: unknown;
  new?: unknown;
}

export interface AdminUser {
  id: string;
  nickname: string;
  banned: boolean;
  muted: boolean;
  verified: string[];
  createdAt: string;
}

export const VERIFICATION_KINDS = ['Verified', 'Official', 'Sponsor', 'BetaTester'] as const;

function isPublicRelease(): boolean {
  return process.env.PUBLIC_RELEASE === 'true';
}

const CONTENT_KINDS = ['games', 'themes', 'rewards', 'badges', 'achievements'] as const;
type ContentKind = (typeof CONTENT_KINDS)[number];

// In-memory audit + stores. TODO: PostgreSQL AdminAction + AuditLog + FeatureFlag.
@Injectable()
export class AdminService {
  private audit: AuditEntry[] = [];
  private flags = new Map<string, boolean>([
    ['workshop_enabled', true],
    ['gifts_enabled', true],
    ['e2ee_enforced', true],
    ['premium_enabled', true],
    ['cases_enabled', true],
  ]);
  private users = new Map<string, AdminUser>();
  private content = new Map<ContentKind, Map<string, Record<string, unknown>>>();

  constructor(
    private readonly profiles: ProfilesService,
    private readonly levels: LevelsService,
    private readonly wallet: WalletService,
    private readonly workshop: WorkshopService,
    private readonly reports: ReportsService,
    private readonly notifications: NotificationsService,
    private readonly analytics: AnalyticsService,
  ) {
    for (const k of CONTENT_KINDS) this.content.set(k, new Map());
    // Seed: 6 достижений (зеркало levels).
    for (const a of ACHIEVEMENTS) {
      this.content.get('achievements')!.set(a.code, { id: a.code, code: a.code, title: a.title, xp: a.xp });
    }
  }

  private log(admin: string, action: string, target: string, extra: Partial<AuditEntry> = {}): AuditEntry {
    const e: AuditEntry = { admin, action, target, timestamp: new Date().toISOString(), ...extra };
    this.audit.push(e);
    return e;
  }

  auditLog(): AuditEntry[] {
    return [...this.audit];
  }

  // ---------- devices ----------
  addDevice(admin: string, deviceId: string) {
    const r = registerDevice(deviceId);
    this.log(admin, 'device.register', deviceId);
    return r;
  }

  // ---------- overview ----------
  overview(admin: string) {
    const a = this.analytics.summary();
    const mem = process.memoryUsage();
    const users = [...this.users.values()];
    const today = new Date().toISOString().slice(0, 10);
    const res = {
      users: {
        total: users.length,
        online: this.analytics.onlineCount(),
        newToday: users.filter((u) => u.createdAt.slice(0, 10) === today).length,
        banned: users.filter((u) => u.banned).length,
      },
      sessions: { invites: a.sessions.invites, acceptedRate: a.sessionsAcceptedRate },
      reports: { clusters: this.reports.clusterCount(), total: this.reports.totalReports() },
      server: {
        uptime: process.uptime(),
        mem: { rss: mem.rss, heapUsed: mem.heapUsed },
        ws: { status: 'up' as const },
      },
    };
    this.log(admin, 'overview', 'server');
    return res;
  }

  // ---------- users ----------
  registerUser(id: string, nickname: string): AdminUser {
    const existing = this.users.get(id);
    if (existing) {
      existing.nickname = nickname;
      return existing;
    }
    const u: AdminUser = { id, nickname, banned: false, muted: false, verified: [], createdAt: new Date().toISOString() };
    this.users.set(id, u);
    this.analytics.record({ type: 'user.register', userId: id });
    return u;
  }

  usersSearch(q?: string): AdminUser[] {
    const all = [...this.users.values()];
    if (!q) return all;
    const needle = q.toLowerCase();
    return all.filter((u) => u.id.toLowerCase().includes(needle) || u.nickname.toLowerCase().includes(needle));
  }

  private needUser(id: string): AdminUser {
    const u = this.users.get(id);
    if (!u) throw new BadRequestException(`admin: user not found: ${id} (register via POST /admin/users/register first)`);
    return u;
  }

  ban(admin: string, userId: string, reason?: string) {
    const u = this.needUser(userId);
    const old = u.banned;
    u.banned = true;
    this.log(admin, 'user.ban', userId, { reason, old: { banned: old }, new: { banned: true } });
    return { userId, banned: true };
  }

  unban(admin: string, userId: string, reason?: string) {
    const u = this.needUser(userId);
    const old = u.banned;
    u.banned = false;
    this.log(admin, 'user.unban', userId, { reason, old: { banned: old }, new: { banned: false } });
    return { userId, banned: false };
  }

  mute(admin: string, userId: string, reason?: string) {
    const u = this.needUser(userId);
    const old = u.muted;
    u.muted = true;
    this.log(admin, 'user.mute', userId, { reason, old: { muted: old }, new: { muted: true } });
    return { userId, muted: true };
  }

  unmute(admin: string, userId: string, reason?: string) {
    const u = this.needUser(userId);
    u.muted = false;
    this.log(admin, 'user.unmute', userId, { reason, old: { muted: true }, new: { muted: false } });
    return { userId, muted: false };
  }

  verify(admin: string, userId: string, kind: string, reason?: string) {
    if (!VERIFICATION_KINDS.includes(kind as never)) {
      throw new BadRequestException(`kind must be one of ${VERIFICATION_KINDS.join(',')}`);
    }
    if (kind === 'BetaTester' && isPublicRelease()) {
      throw new ForbiddenException('BetaTester issuance is closed after public release (PUBLIC_RELEASE=true)');
    }
    const u = this.needUser(userId);
    const old = [...u.verified];
    if (!u.verified.includes(kind)) u.verified.push(kind);
    this.log(admin, 'user.verify', userId, { reason, old: { verified: old }, new: { verified: [...u.verified] } });
    return { userId, verified: [...u.verified] };
  }

  grant(admin: string, userId: string, ember: number, xp: number, reason?: string) {
    this.needUser(userId);
    const tx = ember > 0 ? this.wallet.adminGrant(userId, ember, reason ?? 'admin grant') : null;
    const xpRes = xp > 0 ? this.levels.grantXp(userId, xp) : null;
    this.log(admin, 'economy.grant', userId, { reason, new: { ember, xp } });
    return { userId, ember, xp, tx, xpRes };
  }

  revoke(admin: string, userId: string, ember: number, xp: number, reason?: string) {
    this.needUser(userId);
    const tx = ember > 0 ? this.wallet.adminRevoke(userId, ember, reason ?? 'admin revoke') : null;
    const xpRes = xp > 0 ? this.levels.revokeXp(userId, xp) : null;
    this.log(admin, 'economy.revoke', userId, { reason, new: { ember, xp } });
    return { userId, ember, xp, tx, xpRes };
  }

  // ---------- moderation ----------
  reportClusters(admin: string, clustered = true) {
    this.log(admin, 'moderation.reports.list', 'reports');
    return this.reports.list(clustered);
  }

  workshopReview(admin: string, itemId: string, approve: boolean, reason?: string) {
    const old = this.workshop.get(itemId).state;
    const item = this.workshop.review(itemId, approve, reason);
    this.log(admin, approve ? 'workshop.approve' : 'workshop.reject', itemId, {
      reason,
      old: { state: old },
      new: { state: item.state },
    });
    return item;
  }

  restrict(admin: string, userId: string, scope: string, reason?: string) {
    const u = this.needUser(userId);
    const old = { muted: u.muted, banned: u.banned };
    u.muted = true;
    this.log(admin, 'moderation.restrict', userId, { reason, old, new: { muted: true, banned: u.banned, scope } });
    return { userId, muted: true, scope };
  }

  moderationLog() {
    return this.reports.moderationLog();
  }

  // ---------- verification ----------
  verificationList(admin: string, status?: string) {
    this.log(admin, 'verification.list', 'verification');
    const all = this.profiles.allVerificationRequests();
    return status ? all.filter((r) => r.status === status) : all;
  }

  verificationDecide(admin: string, userId: string, requestId: string, approve: boolean, reason?: string) {
    const reqs = this.profiles.verificationStatus(userId);
    const target = reqs.find((r) => r.id === requestId);
    if (!target) throw new BadRequestException('verification request not found');
    if (target.kind === 'BetaTester' && approve && isPublicRelease()) {
      throw new ForbiddenException('BetaTester issuance is closed after public release (PUBLIC_RELEASE=true)');
    }
    const r = this.profiles.decideVerification(userId, requestId, approve, reason, { admin: true });
    if (approve) {
      const u = this.users.get(userId);
      if (u && !u.verified.includes(target.kind)) u.verified.push(target.kind);
    }
    this.log(admin, approve ? 'verification.approve' : 'verification.reject', `${userId}:${requestId}`, {
      reason,
      old: { status: 'pending', kind: target.kind },
      new: { status: r.status },
    });
    return r;
  }

  // ---------- economy ----------
  redeemCode(admin: string, code: string, amount: number) {
    const r = this.wallet.createRedeemCode(code, amount);
    this.log(admin, 'economy.code.create', code, { new: r });
    return r;
  }

  itemCreate(admin: string, title: string, price = 0, description = '') {
    const item = this.workshop.create(title, 'official', { price, description, official: true });
    this.log(admin, 'economy.item.create', item.id, { new: { title, price } });
    return item;
  }

  setPrice(admin: string, itemId: string, price: number, reason?: string) {
    const old = this.workshop.get(itemId).price;
    const item = this.workshop.setPriceAdmin(itemId, price);
    this.log(admin, 'economy.item.set-price', itemId, { reason, old: { price: old }, new: { price } });
    return item;
  }

  // ---------- content ----------
  contentList(kind: string) {
    this.assertContentKind(kind);
    return [...this.content.get(kind as ContentKind)!.values()];
  }

  contentCreate(admin: string, kind: string, data: Record<string, unknown>) {
    this.assertContentKind(kind);
    const id = String(data.id ?? data.code ?? randomUUID());
    const store = this.content.get(kind as ContentKind)!;
    if (store.has(id)) throw new BadRequestException(`${kind} already exists: ${id}`);
    const entry = { id, ...data };
    store.set(id, entry);
    this.log(admin, `content.${kind}.create`, id, { new: entry });
    return entry;
  }

  contentUpdate(admin: string, kind: string, id: string, patch: Record<string, unknown>) {
    this.assertContentKind(kind);
    const store = this.content.get(kind as ContentKind)!;
    const cur = store.get(id);
    if (!cur) throw new BadRequestException(`${kind} not found: ${id}`);
    if (cur.official === true) throw new ForbiddenException(`official ${kind} entry is read-only: ${id}`);
    const next = { ...cur, ...patch, id };
    store.set(id, next);
    this.log(admin, `content.${kind}.update`, id, { old: cur, new: next });
    return next;
  }

  contentDelete(admin: string, kind: string, id: string) {
    this.assertContentKind(kind);
    const store = this.content.get(kind as ContentKind)!;
    const cur = store.get(id);
    if (!cur) throw new BadRequestException(`${kind} not found: ${id}`);
    if (cur.official === true) throw new ForbiddenException(`official ${kind} entry is read-only: ${id}`);
    store.delete(id);
    this.log(admin, `content.${kind}.delete`, id, { old: cur });
    return { deleted: id };
  }

  private assertContentKind(kind: string): asserts kind is ContentKind {
    if (!(CONTENT_KINDS as readonly string[]).includes(kind)) {
      throw new BadRequestException(`kind must be one of ${CONTENT_KINDS.join(',')}`);
    }
  }

  awardBadge(admin: string, userId: string, badge: { code: string; title: string; category: BadgeCategory }, reason?: string) {
    if (!BADGE_CATEGORIES.includes(badge.category)) {
      throw new BadRequestException(`unknown badge category (expected one of ${BADGE_CATEGORIES.join(',')})`);
    }
    const r = this.profiles.awardBadge(userId, badge, { admin: true });
    this.log(admin, 'content.badge.award', `${userId}:${badge.code}`, { reason, new: r });
    return r;
  }

  awardAchievement(admin: string, userId: string, code: string, reason?: string) {
    const isNew = this.levels.awardAchievement(userId, code);
    this.log(admin, 'content.achievement.award', `${userId}:${code}`, { reason, new: { code, isNew } });
    return { userId, code, awarded: isNew };
  }

  // ---------- analytics ----------
  analyticsSummary(admin: string) {
    this.log(admin, 'analytics.view', 'analytics');
    const a = this.analytics.summary();
    const delivery = this.notifications.deliveryStats();
    return { ...a, notificationDelivery: delivery };
  }

  ingestEvent(admin: string, type: string, userId?: string, data?: Record<string, unknown>) {
    this.analytics.record({ type, userId, data });
    return { recorded: type };
  }

  // ---------- server ----------
  serverStatus(admin: string) {
    this.log(admin, 'server.status', 'server');
    const storagePath = process.env.STORAGE_PATH || './storage';
    let storageExists = false;
    try {
      storageExists = fs.existsSync(storagePath);
    } catch {
      storageExists = false;
    }
    const dbUrl = process.env.DATABASE_URL || '';
    return {
      cpu: os.loadavg(),
      ram: { total: os.totalmem(), free: os.freemem(), process: process.memoryUsage() },
      storage: { path: storagePath, exists: storageExists },
      db: { configured: dbUrl.length > 0, migrations: ['001_init', '002_constraints', '003_seed'] },
      ws: { status: 'up' as const },
      errors: this.analytics.errorCount(),
      uptime: process.uptime(),
      cloudpub: {
        domain: process.env.CLOUDPUB_DOMAIN || null,
        status: process.env.CLOUDPUB_DOMAIN ? ('configured' as const) : ('local' as const),
      },
    };
  }

  // ---------- feature flags ----------
  flagsList(): Record<string, boolean> {
    return Object.fromEntries(this.flags);
  }

  setFlag(admin: string, key: string, enabled: boolean) {
    const old = this.flags.get(key);
    this.flags.set(key, enabled);
    this.log(admin, 'flag.set', key, { old: { enabled: old ?? null }, new: { enabled } });
    return { key, enabled };
  }

  // ---------- beta ----------
  betaList(admin: string) {
    this.log(admin, 'beta.list', 'beta');
    return this.usersSearch().filter((u) => u.verified.includes('BetaTester'));
  }

  betaAward(admin: string, userId: string, reason?: string) {
    if (isPublicRelease()) {
      throw new ForbiddenException('BetaTester issuance is closed after public release (PUBLIC_RELEASE=true)');
    }
    return this.verify(admin, userId, 'BetaTester', reason ?? 'manual beta award');
  }
}

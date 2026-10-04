import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import { assertValidUsername, normalizeUsername } from '../../common/username';

export interface AuthUser {
  id: string;
  email: string; // lowercased
  username: string; // нормализованный handle без @ (оригинальный регистр сохранён)
  passwordHash: string;
  emailVerified: boolean;
  createdAt: string;
}

export interface VerifyCodeEntry {
  code: string;
  expiresAt: number; // ms epoch, TTL 10 мин
  requestedAt: number;
}

export interface UserDevice {
  id: string;
  userId: string;
  deviceInfo: string;
  createdAt: string;
  lastSeenAt: string;
}

export interface UserSession {
  id: string;
  userId: string;
  deviceId: string;
  refreshJti: string;
  createdAt: string;
  lastSeenAt: string;
  revoked: boolean;
}

export const VERIFY_TTL_MS = 10 * 60_000;
export const VERIFY_COOLDOWN_MS = 60_000;
export const LOGIN_RATE_WINDOW_MS = 60_000;
export const LOGIN_RATE_MAX = 5;
export const LOCKOUT_FAILS = 5;
export const LOCKOUT_MS = 15 * 60_000;

// In-memory репозитории с интерфейсом под замену на TypeORM.
// TODO(db): SQL — таблицы users (unique lower(email), unique lower(username)),
// user_devices, user_sessions, email_verify_codes; refresh rotation + blacklist в БД/Redis.
@Injectable()
export class AuthService {
  private usersById = new Map<string, AuthUser>();
  private idByEmail = new Map<string, string>(); // lower(email) -> id
  private idByUsername = new Map<string, string>(); // lower(handle) -> id

  private verifyCodes = new Map<string, VerifyCodeEntry>(); // lower(email) -> entry
  private verifyCooldown = new Map<string, number>(); // lower(email) -> ts ms

  private refreshByJti = new Map<string, { userId: string; sessionId: string; token: string }>();
  private tokenBlacklist = new Set<string>(); // отозванные access/refresh токены (строки)
  private accessByUser = new Map<string, Set<string>>(); // userId -> access токены (для logout-all)

  private devices = new Map<string, UserDevice>();
  private sessions = new Map<string, UserSession>();

  private loginHits = new Map<string, number[]>(); // ip -> timestamps ms
  private fails = new Map<string, { count: number; lockedUntil: number }>(); // lower(identifier) -> lockout

  // ---------- register ----------

  async register(email: string, username: string, password: string, deviceInfo = 'unknown') {
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      throw new BadRequestException({ code: 'INVALID_EMAIL', message: 'invalid email' });
    }
    let handle: string;
    try {
      handle = assertValidUsername(username);
    } catch {
      throw new BadRequestException({
        code: 'INVALID_USERNAME',
        message: 'username must be min 4 chars of [a-zA-Z0-9_.-] with optional leading @',
      });
    }
    if (typeof password !== 'string' || password.length < 6 || password.length > 128) {
      throw new BadRequestException({ code: 'WEAK_PASSWORD', message: 'password must be 6..128 chars' });
    }
    if (this.idByEmail.has(cleanEmail)) {
      throw new BadRequestException({ code: 'EMAIL_TAKEN', message: 'email taken' });
    }
    if (this.idByUsername.has(handle.toLowerCase())) {
      throw new BadRequestException({ code: 'USERNAME_TAKEN', message: 'username taken' });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    const user: AuthUser = {
      id: randomUUID(),
      email: cleanEmail,
      username: handle,
      passwordHash,
      emailVerified: false,
      createdAt: new Date().toISOString(),
    };
    this.usersById.set(user.id, user);
    this.idByEmail.set(cleanEmail, user.id);
    this.idByUsername.set(handle.toLowerCase(), user.id);
    return { id: user.id, email: user.email, username: '@' + user.username, emailVerified: false };
  }

  // ---------- login / lockout / rate-limit ----------

  private failKey(identifier: string): string {
    return identifier.trim().toLowerCase();
  }

  private checkLockout(identifier: string): void {
    const slot = this.fails.get(this.failKey(identifier));
    if (slot && Date.now() < slot.lockedUntil) {
      const sec = Math.ceil((slot.lockedUntil - Date.now()) / 1000);
      throw new ForbiddenException({ code: 'LOCKED_OUT', message: `locked out, retry in ${sec}s` });
    }
  }

  private recordFailure(identifier: string): void {
    const key = this.failKey(identifier);
    const slot = this.fails.get(key) ?? { count: 0, lockedUntil: 0 };
    slot.count += 1;
    if (slot.count >= LOCKOUT_FAILS) {
      slot.lockedUntil = Date.now() + LOCKOUT_MS;
      slot.count = 0; // счётчик сбрасываем после лока
    }
    this.fails.set(key, slot);
  }

  private recordSuccess(identifier: string): void {
    this.fails.delete(this.failKey(identifier));
  }

  /** Rate-limit логина: 5 попыток/мин/IP. Бросает 429 при превышении. */
  checkLoginRateLimit(ip: string): void {
    const now = Date.now();
    const arr = (this.loginHits.get(ip) ?? []).filter((t) => now - t < LOGIN_RATE_WINDOW_MS);
    if (arr.length >= LOGIN_RATE_MAX) {
      throw new BadRequestException({ code: 'TOO_MANY_REQUESTS', message: 'login rate limit 5/min' });
    }
    arr.push(now);
    this.loginHits.set(ip, arr);
  }

  private findUser(identifier: string): AuthUser | null {
    const clean = identifier.trim();
    if (clean.includes('@') && clean.includes('.')) {
      // email-путь: может быть и @username без точки — тогда это не email
      const id = this.idByEmail.get(clean.toLowerCase());
      return (id && this.usersById.get(id)) || null;
    }
    const handle = normalizeUsername(clean).toLowerCase();
    const byName = this.idByUsername.get(handle);
    if (byName) return this.usersById.get(byName) ?? null;
    const byMail = this.idByEmail.get(clean.toLowerCase());
    return (byMail && this.usersById.get(byMail)) || null;
  }

  async login(identifier: string, password: string, jwt: JwtService, ip = 'unknown', deviceInfo = 'unknown') {
    this.checkLoginRateLimit(ip);
    this.checkLockout(identifier);
    const user = this.findUser(identifier);
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      this.recordFailure(identifier);
      throw new UnauthorizedException({ code: 'INVALID_CREDENTIALS', message: 'invalid credentials' });
    }
    this.recordSuccess(identifier);
    const device = this.upsertDevice(user.id, deviceInfo);
    return this.issueTokens(user.id, device.id, jwt);
  }

  // ---------- tokens: rotation + blacklist ----------

  private async issueTokens(userId: string, deviceId: string, jwt: JwtService) {
    const accessJti = randomUUID();
    const refreshJti = randomUUID();
    const access = await jwt.signAsync(
      { sub: userId, jti: accessJti },
      { secret: process.env.JWT_SECRET || 'dev-only-change-me', expiresIn: '15m' },
    );
    const refresh = await jwt.signAsync(
      { sub: userId, kind: 'refresh', jti: refreshJti },
      { secret: process.env.JWT_REFRESH_SECRET || 'dev-only-change-me-refresh', expiresIn: '30d' },
    );
    const session: UserSession = {
      id: randomUUID(),
      userId,
      deviceId,
      refreshJti,
      createdAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
      revoked: false,
    };
    this.sessions.set(session.id, session);
    this.refreshByJti.set(refreshJti, { userId, sessionId: session.id, token: refresh });
    let set = this.accessByUser.get(userId);
    if (!set) {
      set = new Set();
      this.accessByUser.set(userId, set);
    }
    set.add(access);
    return { accessToken: access, refreshToken: refresh, userId, sessionId: session.id };
  }

  /** Валидация access-токена с учётом blacklist. Возвращает userId. */
  async validateAccess(token: string, jwt: JwtService): Promise<string> {
    if (this.tokenBlacklist.has(token)) {
      throw new UnauthorizedException({ code: 'TOKEN_REVOKED', message: 'token revoked' });
    }
    try {
      const payload = await jwt.verifyAsync<{ sub: string }>(token, {
        secret: process.env.JWT_SECRET || 'dev-only-change-me',
      });
      return payload.sub;
    } catch {
      throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'invalid token' });
    }
  }

  isBlacklisted(token: string): boolean {
    return this.tokenBlacklist.has(token);
  }

  /** Refresh с rotation: старый refresh отзывается и заносится в blacklist, выдаётся новая пара. */
  async refresh(refreshToken: string, jwt: JwtService) {
    if (this.tokenBlacklist.has(refreshToken)) {
      throw new UnauthorizedException({ code: 'TOKEN_REVOKED', message: 'refresh revoked' });
    }
    let payload: { sub: string; jti: string; kind?: string };
    try {
      payload = await jwt.verifyAsync(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET || 'dev-only-change-me-refresh',
      });
    } catch {
      throw new UnauthorizedException({ code: 'REFRESH_EXPIRED', message: 'refresh expired' });
    }
    if (payload.kind !== 'refresh' || !payload.jti) {
      throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'not a refresh token' });
    }
    const rec = this.refreshByJti.get(payload.jti);
    if (!rec || rec.token !== refreshToken) {
      throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'unknown refresh token' });
    }
    const session = this.sessions.get(rec.sessionId);
    if (!session || session.revoked) {
      throw new UnauthorizedException({ code: 'TOKEN_REVOKED', message: 'session revoked' });
    }
    // rotation: отзываем старый
    this.tokenBlacklist.add(refreshToken);
    this.refreshByJti.delete(payload.jti);
    session.revoked = true;
    const user = this.usersById.get(rec.userId);
    if (!user) throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'unknown user' });
    return this.issueTokens(user.id, session.deviceId, jwt);
  }

  /** Logout одной сессии по refresh-токену. */
  async logout(refreshToken: string): Promise<{ revoked: boolean }> {
    this.tokenBlacklist.add(refreshToken);
    for (const [jti, rec] of this.refreshByJti) {
      if (rec.token === refreshToken) {
        this.refreshByJti.delete(jti);
        const s = this.sessions.get(rec.sessionId);
        if (s) s.revoked = true;
        return { revoked: true };
      }
    }
    return { revoked: true };
  }

  /** Logout-all: отозвать все сессии и токены пользователя. */
  async logoutAll(userId: string): Promise<{ revokedSessions: number }> {
    let n = 0;
    for (const s of this.sessions.values()) {
      if (s.userId === userId && !s.revoked) {
        s.revoked = true;
        n += 1;
      }
    }
    for (const [jti, rec] of [...this.refreshByJti]) {
      if (rec.userId === userId) {
        this.tokenBlacklist.add(rec.token);
        this.refreshByJti.delete(jti);
      }
    }
    const acc = this.accessByUser.get(userId);
    if (acc) {
      for (const t of acc) this.tokenBlacklist.add(t);
      this.accessByUser.set(userId, new Set());
    }
    return { revokedSessions: n };
  }

  listSessions(userId: string): UserSession[] {
    return [...this.sessions.values()].filter((s) => s.userId === userId && !s.revoked);
  }

  listDevices(userId: string): UserDevice[] {
    return [...this.devices.values()].filter((d) => d.userId === userId);
  }

  private upsertDevice(userId: string, deviceInfo: string): UserDevice {
    const existing = [...this.devices.values()].find(
      (d) => d.userId === userId && d.deviceInfo === deviceInfo,
    );
    if (existing) {
      existing.lastSeenAt = new Date().toISOString();
      return existing;
    }
    const d: UserDevice = {
      id: randomUUID(),
      userId,
      deviceInfo,
      createdAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
    };
    this.devices.set(d.id, d);
    return d;
  }

  // ---------- email verify: cooldown 60с, TTL 10 мин ----------

  requestVerifyCode(email: string): { cooldownSec: number; expiresInSec: number } {
    const key = email.trim().toLowerCase();
    const last = this.verifyCooldown.get(key) ?? 0;
    const elapsed = Date.now() - last;
    if (elapsed < VERIFY_COOLDOWN_MS) {
      throw new BadRequestException({
        code: 'VERIFY_COOLDOWN',
        message: `cooldown: ${Math.ceil((VERIFY_COOLDOWN_MS - elapsed) / 1000)}s`,
      });
    }
    const code = String(Math.floor(100000 + Math.random() * 900000));
    this.verifyCodes.set(key, { code, expiresAt: Date.now() + VERIFY_TTL_MS, requestedAt: Date.now() });
    this.verifyCooldown.set(key, Date.now());
    // TODO(db): отправка кода через push/APNs + персист в email_verify_codes.
    return { cooldownSec: 60, expiresInSec: 600 };
  }

  /** Только для тестов: подсмотреть текущий код (в прод-ответах код не возвращается). */
  peekVerifyCode(email: string): string | null {
    return this.verifyCodes.get(email.trim().toLowerCase())?.code ?? null;
  }

  verifyEmail(email: string, code: string): { verified: boolean } {
    const key = email.trim().toLowerCase();
    const entry = this.verifyCodes.get(key);
    if (!entry) throw new BadRequestException({ code: 'NO_CODE', message: 'no verify code requested' });
    if (Date.now() > entry.expiresAt) {
      this.verifyCodes.delete(key);
      throw new BadRequestException({ code: 'CODE_EXPIRED', message: 'verify code expired (TTL 10m)' });
    }
    if (entry.code !== code) {
      throw new BadRequestException({ code: 'CODE_MISMATCH', message: 'wrong verify code' });
    }
    this.verifyCodes.delete(key);
    const id = this.idByEmail.get(key);
    if (id) {
      const u = this.usersById.get(id);
      if (u) u.emailVerified = true;
    }
    return { verified: true };
  }

  getUserById(id: string): AuthUser | null {
    return this.usersById.get(id) ?? null;
  }
}

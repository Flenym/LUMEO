import { BadRequestException, Injectable } from '@nestjs/common';
import {
  LastSeenMode,
  StatusColor,
  StatusTimer,
  formatLastSeen,
  isInactive,
  isValidColor,
  normalizeStatus,
  stripEmoji,
  timerToMs,
} from '../../common/engines/status.engine';
import { isPublicTextAllowed } from '../../common/engines/moderation';

export interface StatusRecord {
  userId: string;
  color: StatusColor;
  text: string;
  updatedAt: string;
  expiresAt: string | null;
  prevColor: StatusColor;
  prevText: string;
  defaultColor: StatusColor;
  defaultText: string;
  allowEmoji: boolean;
  returnToPrev: boolean;
  lastSeenAt: number | null;
  lastSeenMode: LastSeenMode;
  inactive: boolean;
}

export interface SetStatusOpts {
  allowEmoji?: boolean; // default false — emoji режутся
  timer?: StatusTimer; // 15m/30m/1h/2h/until/none
  until?: string | number | null; // для timer=until — ISO или epoch ms
  defaultColor?: StatusColor;
  defaultText?: string;
  returnToPrev?: boolean; // default true — авто-возврат к prev, иначе к default
  lastSeenMode?: LastSeenMode;
  bannedWords?: string[];
}

const BANNED_DEFAULT: string[] = [];

// In-memory репозиторий с интерфейсом под замену на TypeORM.
// TODO(db): SQL — таблица user_statuses (user_id PK, color, text, expires_at, prev_*, default_*, last_seen_*).
@Injectable()
export class StatusesService {
  private statuses = new Map<string, StatusRecord>();

  set(userId: string, color: StatusColor, text: string, opts: SetStatusOpts = {}): StatusRecord {
    if (!isValidColor(color)) {
      throw new BadRequestException({ code: 'INVALID_COLOR', message: 'color must be green|yellow|red' });
    }
    const allowEmoji = opts.allowEmoji ?? false;
    let clean = typeof text === 'string' ? text.trim() : '';
    if (!allowEmoji) clean = stripEmoji(clean).trim();
    if (clean.length > 140) {
      throw new BadRequestException({ code: 'TEXT_TOO_LONG', message: 'status text max 140 chars' });
    }
    // Модерация публичного текста (пустой текст = сброс, модерацию не проходит как ошибка).
    if (clean.length > 0) {
      const check = isPublicTextAllowed(clean, opts.bannedWords ?? BANNED_DEFAULT);
      if (!check.allowed) {
        throw new BadRequestException({ code: 'MODERATION_REJECTED', message: `status rejected: ${check.reason}` });
      }
    }
    const prev = this.statuses.get(userId);
    const normalized = normalizeStatus(color, clean);
    const now = Date.now();
    const expiresAt = this.computeExpiresAt(opts, now);
    const rec: StatusRecord = {
      userId,
      color: normalized.color,
      text: normalized.text,
      updatedAt: normalized.updatedAt,
      expiresAt: expiresAt !== null ? new Date(expiresAt).toISOString() : null,
      prevColor: prev?.color ?? opts.defaultColor ?? 'green',
      prevText: prev?.text ?? opts.defaultText ?? '',
      defaultColor: opts.defaultColor ?? prev?.defaultColor ?? 'green',
      defaultText: opts.defaultText ?? prev?.defaultText ?? '',
      allowEmoji,
      returnToPrev: opts.returnToPrev ?? prev?.returnToPrev ?? true,
      lastSeenAt: prev?.lastSeenAt ?? now,
      lastSeenMode: opts.lastSeenMode ?? prev?.lastSeenMode ?? 'recent',
      inactive: false,
    };
    this.statuses.set(userId, rec);
    return rec;
  }

  private computeExpiresAt(opts: SetStatusOpts, now: number): number | null {
    const timer = opts.timer ?? 'none';
    if (timer === 'until') {
      if (opts.until === undefined || opts.until === null) return null;
      const ms = typeof opts.until === 'number' ? opts.until : Date.parse(opts.until);
      if (!Number.isFinite(ms) || ms <= now) return null;
      return ms;
    }
    return timerToMs(timer) !== null ? now + (timerToMs(timer) as number) : null;
  }

  /** Отметить lastSeen (вызывается presence/gateway). Текст статуса не меняется. */
  touchLastSeen(userId: string, mode?: LastSeenMode, atMs = Date.now()): { lastSeenAt: string } {
    const rec = this.statuses.get(userId);
    const at = new Date(atMs).toISOString();
    if (rec) {
      rec.lastSeenAt = atMs;
      if (mode) rec.lastSeenMode = mode;
      rec.inactive = false;
    } else {
      this.statuses.set(userId, {
        userId,
        color: 'green',
        text: '',
        updatedAt: new Date(atMs).toISOString(),
        expiresAt: null,
        prevColor: 'green',
        prevText: '',
        defaultColor: 'green',
        defaultText: '',
        allowEmoji: false,
        returnToPrev: true,
        lastSeenAt: atMs,
        lastSeenMode: mode ?? 'recent',
        inactive: false,
      });
    }
    return { lastSeenAt: at };
  }

  setLastSeenMode(userId: string, mode: LastSeenMode): { mode: LastSeenMode } {
    const rec = this.ensure(userId);
    rec.lastSeenMode = mode;
    return { mode };
  }

  /** Получить статус с авто-истечением и флагом inactive (текст меняется только по таймеру). */
  get(userId: string, nowMs = Date.now()) {
    const rec = this.ensure(userId);
    // Авто-возврат по таймеру.
    if (rec.expiresAt && nowMs >= Date.parse(rec.expiresAt)) {
      const backColor = rec.returnToPrev ? rec.prevColor : rec.defaultColor;
      const backText = rec.returnToPrev ? rec.prevText : rec.defaultText;
      rec.prevColor = rec.color;
      rec.prevText = rec.text;
      rec.color = backColor;
      rec.text = backText;
      rec.updatedAt = new Date(nowMs).toISOString();
      rec.expiresAt = null;
    }
    const inactive = rec.lastSeenAt === null ? true : isInactive(rec.lastSeenAt, nowMs);
    rec.inactive = inactive;
    return {
      ...rec,
      inactive,
      lastSeen: formatLastSeen(rec.lastSeenAt, nowMs, rec.lastSeenMode),
    };
  }

  /** Вид для другого пользователя с учётом блокировки (blocked=true скрывает всё). */
  getForViewer(userId: string, opts: { blocked?: boolean; areFriends?: boolean } = {}, nowMs = Date.now()) {
    if (opts.blocked) {
      return { userId, color: 'green' as StatusColor, text: '', hidden: true, lastSeen: null, inactive: null };
    }
    const full = this.get(userId, nowMs);
    void opts.areFriends;
    return { ...full, hidden: false };
  }

  clear(userId: string): { cleared: boolean } {
    const rec = this.statuses.get(userId);
    if (!rec) return { cleared: false };
    rec.prevColor = rec.color;
    rec.prevText = rec.text;
    rec.color = rec.defaultColor;
    rec.text = rec.defaultText;
    rec.updatedAt = new Date().toISOString();
    rec.expiresAt = null;
    return { cleared: true };
  }

  private ensure(userId: string): StatusRecord {
    let rec = this.statuses.get(userId);
    if (!rec) {
      const now = Date.now();
      rec = {
        userId,
        color: 'green',
        text: '',
        updatedAt: new Date(now).toISOString(),
        expiresAt: null,
        prevColor: 'green',
        prevText: '',
        defaultColor: 'green',
        defaultText: '',
        allowEmoji: false,
        returnToPrev: true,
        lastSeenAt: null,
        lastSeenMode: 'recent',
        inactive: true,
      };
      this.statuses.set(userId, rec);
    }
    return rec;
  }
}

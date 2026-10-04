// Чистая логика статусов/presence. Без Nest-зависимостей — покрыта unit-тестами.

export type StatusColor = 'green' | 'yellow' | 'red';

export interface NormalizedStatus {
  color: StatusColor;
  text: string;
  updatedAt: string; // ISO
}

const VALID_COLORS: StatusColor[] = ['green', 'yellow', 'red'];

/** Проверка допустимости цвета. */
export function isValidColor(color: unknown): color is StatusColor {
  return typeof color === 'string' && (VALID_COLORS as string[]).includes(color);
}

/** Нормализация статуса: trim текста, fallback цвета, простановка updatedAt. */
export function normalizeStatus(color: unknown, text: unknown): NormalizedStatus {
  const safeColor: StatusColor = isValidColor(color) ? color : 'green';
  const safeText = typeof text === 'string' ? text.trim().slice(0, 140) : '';
  return { color: safeColor, text: safeText, updatedAt: new Date().toISOString() };
}

/** TTL статуса по умолчанию — 24 часа. */
export const STATUS_TTL_MS = 24 * 60 * 60 * 1000;

/** Нужно ли автоистечение статуса. */
export function shouldAutoExpire(updatedAtMs: number, nowMs: number, ttlMs = STATUS_TTL_MS): boolean {
  if (!Number.isFinite(updatedAtMs) || !Number.isFinite(nowMs)) return false;
  return nowMs - updatedAtMs >= ttlMs;
}

/** Статус по умолчанию после истечения (сброс к зелёному). */
export function resolveAfterExpiry(
  prev: NormalizedStatus,
  def: NormalizedStatus = { color: 'green', text: '', updatedAt: new Date().toISOString() },
): NormalizedStatus {
  void prev;
  return { ...def, updatedAt: new Date().toISOString() };
}

const INACTIVE_AFTER_MS = 5 * 60 * 1000;

/** Неактивен, если lastSeen старше 5 минут. */
export function isInactive(lastSeenAtMs: number, nowMs: number): boolean {
  if (!Number.isFinite(lastSeenAtMs) || !Number.isFinite(nowMs)) return true;
  return nowMs - lastSeenAtMs > INACTIVE_AFTER_MS;
}

// ---- Tier1: emoji-флаг, таймеры, lastSeen-режимы ----

/** Вырезать emoji из текста (флаг allowEmoji=false по умолчанию). */
export function stripEmoji(text: string): string {
  // Покрывает основные emoji-диапазоны + variation selector + ZWJ.
  return text
    .replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{200D}]/gu, '')
    .replace(/\s{2,}/g, ' ');
}

export type StatusTimer = '15m' | '30m' | '1h' | '2h' | 'until' | 'none';

/** Длительность таймера статуса в мс (until/none = null = без авто-истечения по таймеру). */
export function timerToMs(timer: StatusTimer): number | null {
  switch (timer) {
    case '15m':
      return 15 * 60_000;
    case '30m':
      return 30 * 60_000;
    case '1h':
      return 60 * 60_000;
    case '2h':
      return 2 * 60 * 60_000;
    default:
      return null;
  }
}

export type LastSeenMode = 'exact' | 'recent' | 'hidden';

/**
 * Форматирование lastSeen по режиму приватности.
 * exact — ISO-строка; recent — корзина (just_now/recently/today/this_week/long_ago);
 * hidden — null. Возвращает только флаг видимости, текст статуса не меняет.
 */
export function formatLastSeen(lastSeenAtMs: number | null, nowMs: number, mode: LastSeenMode): string | null {
  if (mode === 'hidden' || lastSeenAtMs === null || !Number.isFinite(lastSeenAtMs)) return null;
  if (mode === 'exact') return new Date(lastSeenAtMs).toISOString();
  const diff = nowMs - lastSeenAtMs;
  if (diff < 60_000) return 'just_now';
  if (diff < 60 * 60_000) return 'recently';
  if (diff < 24 * 60 * 60_000) return 'today';
  if (diff < 7 * 24 * 60 * 60_000) return 'this_week';
  return 'long_ago';
}

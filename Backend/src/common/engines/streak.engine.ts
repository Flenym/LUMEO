// Чистая логика streak. Даты в формате YYYY-MM-DD, сравнение tz-safe (UTC-полночь).
// Дубли в один день не засчитываются: diff 0 дней возвращает streak без изменений.

export interface StreakResult {
  streak: number;
  broken: boolean;
}

function parseDay(dateStr: string): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr);
  if (!m) return null;
  const ms = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(ms) ? null : ms;
}

/** Текущий UTC-день строкой YYYY-MM-DD (timezone-safe: всегда UTC). */
export function todayStr(now: Date = new Date()): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, '0');
  const d = String(now.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Разница в целых UTC-днях между двумя dateStr (b - a). */
export function diffDays(aStr: string, bStr: string): number {
  const a = parseDay(aStr);
  const b = parseDay(bStr);
  if (a === null) throw new Error('invalid aStr, expected YYYY-MM-DD');
  if (b === null) throw new Error('invalid bStr, expected YYYY-MM-DD');
  return Math.round((b - a) / 86_400_000);
}

/**
 * Обновление стрика.
 * - lastDateStr null => первый день, streak=1
 * - diff 0 дней (тот же день) => streak неизменен, broken=false (защита от дублей)
 * - diff 1 день => streak+1
 * - diff >1 => broken=true, streak=1
 */
export function updateStreak(
  lastDateStr: string | null,
  todayStrParam: string,
  currentStreak = 0,
): StreakResult {
  const today = parseDay(todayStrParam);
  if (today === null) throw new Error('invalid todayStr, expected YYYY-MM-DD');
  if (lastDateStr === null) return { streak: 1, broken: false };
  const last = parseDay(lastDateStr);
  if (last === null) throw new Error('invalid lastDateStr, expected YYYY-MM-DD');
  const diff = Math.round((today - last) / 86_400_000);
  if (diff <= 0) return { streak: currentStreak, broken: false };
  if (diff === 1) return { streak: currentStreak + 1, broken: false };
  return { streak: 1, broken: true };
}

/**
 * Засчитывается ли активность дня сквада: true только если пользователь
 * реально joined хотя бы одну сессию (sessionsJoinedCount > 0).
 * Принимает boolean (legacy) или число присоединений.
 */
export function squadDayActivity(sessionsJoined: boolean | number): boolean {
  if (typeof sessionsJoined === 'number') {
    return Number.isFinite(sessionsJoined) && sessionsJoined > 0;
  }
  return sessionsJoined === true;
}

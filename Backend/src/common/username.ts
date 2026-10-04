// Общие правила username для Tier1.
// Формат: опциональный ведущий `@`, далее минимум 4 символа из [a-zA-Z0-9_.-].
// Хранится нормализованный handle БЕЗ `@` (сравнение case-insensitive).
// TODO(db): SQL unique constraint на lower(handle) + отдельный unique на lower(email).

export const USERNAME_RE = /^[a-zA-Z0-9_.-]{4,}$/;
export const USERNAME_MIN = 4;

/** Убирает ведущий `@` и пробелы по краям. */
export function normalizeUsername(input: unknown): string {
  if (typeof input !== 'string') return '';
  const t = input.trim();
  return t.startsWith('@') ? t.slice(1) : t;
}

/** true, если handle валиден (мин. 4, только [a-zA-Z0-9_.-]). */
export function isValidUsername(input: unknown): boolean {
  const h = normalizeUsername(input);
  return USERNAME_RE.test(h);
}

/** Бросает Error с code=INVALID_USERNAME, если handle невалиден. Возвращает нормализованный handle. */
export function assertValidUsername(input: unknown): string {
  const h = normalizeUsername(input);
  if (!USERNAME_RE.test(h)) {
    const err = new Error(
      'Invalid username: min 4 chars, allowed [a-zA-Z0-9_.-], optional leading @',
    );
    (err as Error & { code?: string }).code = 'INVALID_USERNAME';
    throw err;
  }
  return h;
}

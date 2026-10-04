// Модерация публичных текстов (статусы, профили, Workshop).
// ВАЖНО: НЕ применять к чатам — чаты E2EE, сервер хранит только metadata,
// plaintext сообщений сервер не читает и не модерирует.

import { createHash } from 'crypto';

export interface ModerationResult {
  allowed: boolean;
  reason?: string;
}

/** Проверка текста по списку запрещённых слов (case-insensitive, подстрока). */
export function isPublicTextAllowed(text: string, bannedWords: string[] = []): ModerationResult {
  if (typeof text !== 'string' || text.trim().length === 0) {
    return { allowed: false, reason: 'empty' };
  }
  if (text.length > 5000) return { allowed: false, reason: 'too_long' };
  const lower = text.toLowerCase();
  for (const w of bannedWords) {
    const word = w.toLowerCase().trim();
    if (word && lower.includes(word)) {
      return { allowed: false, reason: `banned_word:${w}` };
    }
  }
  return { allowed: true };
}

/**
 * clusterId жалобы: hash(type + targetId). Повторная жалоба на ту же цель
 * того же типа попадает в тот же кластер (count++), а не создаёт новый ряд.
 * reporterId и reason в хэш НЕ входят.
 */
export function reportClusterId(type: string, targetId: string): string {
  return createHash('sha256').update(`${type}:${targetId}`).digest('hex').slice(0, 16);
}

/**
 * E2EE-валидатор для message endpoints: сервер хранит ТОЛЬКО MessageMetadata.
 * Любой непустой plaintext body отвергается ошибкой USE_E2EE
 * (пустой/отсутствующий body — ок, т.к. контент идёт через ciphertext_ref).
 */
export function assertNoPlaintext(body: unknown): void {
  if (body === undefined || body === null) return;
  if (typeof body === 'string') {
    if (body.length > 0) {
      throw new Error('USE_E2EE: plaintext message body is forbidden, send ciphertext only');
    }
    return;
  }
  const serialized = JSON.stringify(body) ?? '';
  if (serialized.length > 2) {
    throw new Error('USE_E2EE: plaintext message body is forbidden, send ciphertext only');
  }
}

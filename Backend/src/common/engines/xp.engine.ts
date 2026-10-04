// Чистая логика XP / уровней / рангов.

export type XpEvent =
  | 'session_complete'
  | 'session_join'
  | 'streak_day'
  | 'achievement'
  | 'friend_add'
  | 'squad_create'
  | 'message_sent'
  | 'workshop_publish';

const XP_TABLE: Record<string, number> = {
  session_complete: 50,
  session_join: 10,
  streak_day: 5,
  achievement: 30,
  friend_add: 5,
  squad_create: 15,
  workshop_publish: 25,
  // Спам-защита: за сообщения XP не начисляем.
  message_sent: 0,
};

/** XP за событие; неизвестные события дают 0. */
export function xpForEvent(event: string): number {
  return XP_TABLE[event] ?? 0;
}

/** Уровень: floor(sqrt(xp / 100)) + 1. xp<0 трактуем как 0. */
export function levelForXp(xp: number): number {
  const safe = Math.max(0, Math.floor(xp));
  return Math.floor(Math.sqrt(safe / 100)) + 1;
}

export type Rank =
  | 'Wood'
  | 'Stone'
  | 'Iron'
  | 'Bronze'
  | 'Silver'
  | 'Gold'
  | 'Platinum'
  | 'Diamond'
  | 'Master'
  | 'Grandmaster'
  | 'Legend';

/** Пороги рангов по уровню (минимальный уровень для ранга). */
export const RANK_LEVEL_THRESHOLDS: { rank: Rank; minLevel: number }[] = [
  { rank: 'Wood', minLevel: 1 },
  { rank: 'Stone', minLevel: 2 },
  { rank: 'Iron', minLevel: 3 },
  { rank: 'Bronze', minLevel: 5 },
  { rank: 'Silver', minLevel: 10 },
  { rank: 'Gold', minLevel: 13 },
  { rank: 'Platinum', minLevel: 16 },
  { rank: 'Diamond', minLevel: 20 },
  { rank: 'Master', minLevel: 23 },
  { rank: 'Grandmaster', minLevel: 26 },
  { rank: 'Legend', minLevel: 30 },
];

/**
 * Пороги рангов по суммарному XP (для витрин/прогресса).
 * Из ТЗ: Wood 0, Stone 100, Iron 250, Bronze 500, Silver 1000, Gold 2000,
 * Platinum 3500, Diamond 5500, Master 8000, Grandmaster 12000, Legend 18000.
 */
export const RANK_XP_THRESHOLDS: { rank: Rank; minXp: number }[] = [
  { rank: 'Wood', minXp: 0 },
  { rank: 'Stone', minXp: 100 },
  { rank: 'Iron', minXp: 250 },
  { rank: 'Bronze', minXp: 500 },
  { rank: 'Silver', minXp: 1000 },
  { rank: 'Gold', minXp: 2000 },
  { rank: 'Platinum', minXp: 3500 },
  { rank: 'Diamond', minXp: 5500 },
  { rank: 'Master', minXp: 8000 },
  { rank: 'Grandmaster', minXp: 12000 },
  { rank: 'Legend', minXp: 18000 },
];

/** Ранг по уровню (возвращает базовое имя без дивизиона). */
export function rankForLevel(level: number): Rank {
  let current: Rank = 'Wood';
  for (const t of RANK_LEVEL_THRESHOLDS) {
    if (level >= t.minLevel) current = t.rank;
    else break;
  }
  return current;
}

/** Ранг по суммарному XP (витринный, по порогам ТЗ). */
export function rankForXp(xp: number): Rank {
  const safe = Math.max(0, Math.floor(xp));
  let current: Rank = 'Wood';
  for (const t of RANK_XP_THRESHOLDS) {
    if (safe >= t.minXp) current = t.rank;
    else break;
  }
  return current;
}

export type Division = 'I' | 'II' | 'III';

/**
 * Дивизион внутри ранга по уровню: диапазон [текущий порог, следующий порог)
 * делится на трети. Верхняя треть (ближе к следующему рангу) — I,
 * средняя — II, нижняя — III. У Legend (верхнего ранга) всегда I.
 */
export function rankDivision(level: number): Division {
  const idx = RANK_LEVEL_THRESHOLDS.findIndex(
    (t, i) =>
      level >= t.minLevel &&
      (i === RANK_LEVEL_THRESHOLDS.length - 1 || level < RANK_LEVEL_THRESHOLDS[i + 1].minLevel),
  );
  if (idx === -1) return 'III';
  if (idx === RANK_LEVEL_THRESHOLDS.length - 1) return 'I';
  const lo = RANK_LEVEL_THRESHOLDS[idx].minLevel;
  const hi = RANK_LEVEL_THRESHOLDS[idx + 1].minLevel;
  const span = hi - lo;
  const pos = (level - lo) / span;
  if (pos >= 2 / 3) return 'I';
  if (pos >= 1 / 3) return 'II';
  return 'III';
}

/** Отображаемый ранг: "Silver II". */
export function rankDisplay(level: number): string {
  return `${rankForLevel(level)} ${rankDivision(level)}`;
}

/** Минимальный суммарный XP для ранга (витринный порог ТЗ). */
export function minXpForRank(rank: Rank): number {
  return RANK_XP_THRESHOLDS.find((t) => t.rank === rank)?.minXp ?? 0;
}

/**
 * Lumeo Shared — constants.
 * Backend (NestJS) and iOS must import from here, not hardcode.
 */
import type { SessionState } from './enums';

export const API_VERSION = 'v1' as const;
export const API_PREFIX = `/api/${API_VERSION}` as const;

export const DEFAULT_PORT = 5267 as const;

/** Configurable via env CURRENCY_NAME. Default: EMBER. */
const ENV_CURRENCY = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process
  ?.env?.CURRENCY_NAME;
export const CURRENCY_NAME = ENV_CURRENCY ?? 'EMBER';

export const MAX_SQUAD_MEMBERS = 200 as const;

export const USERNAME_MIN = 4 as const;
/** Latin letters, digits, `_`, `-`, `.` (dot only if backend routing allows — see README ТЗ §8). */
export const USERNAME_REGEX = /^[a-zA-Z0-9_-]{3,}[a-zA-Z0-9_.-]*$/;
/** Simpler strict check used by forms: min 4, allowed chars a-zA-Z0-9_-. */
export const USERNAME_STRICT_REGEX = /^[a-zA-Z0-9_.-]{4,32}$/;

export const STATUS_MAX_LEN = 140 as const;

export const SESSION_STATES: readonly SessionState[] = [
  'Draft',
  'Inviting',
  'Waiting',
  'Ready',
  'Live',
  'Paused',
  'Finished',
  'Cancelled',
] as const;

/** Starter catalog from ТЗ §52 (19 titles). Slugs are canonical. */
export const STARTER_GAMES: readonly { name: string; slug: string }[] = [
  { name: 'Fortnite', slug: 'fortnite' },
  { name: 'Minecraft', slug: 'minecraft' },
  { name: 'Valorant', slug: 'valorant' },
  { name: 'Counter-Strike 2', slug: 'counter-strike-2' },
  { name: 'Roblox', slug: 'roblox' },
  { name: 'Apex Legends', slug: 'apex-legends' },
  { name: 'Call of Duty', slug: 'call-of-duty' },
  { name: 'GTA', slug: 'gta' },
  { name: 'Rocket League', slug: 'rocket-league' },
  { name: 'Overwatch', slug: 'overwatch' },
  { name: 'PUBG', slug: 'pubg' },
  { name: 'Terraria', slug: 'terraria' },
  { name: 'Sea of Thieves', slug: 'sea-of-thieves' },
  { name: 'Rainbow Six Siege', slug: 'rainbow-six-siege' },
  { name: 'Destiny 2', slug: 'destiny-2' },
  { name: 'The Finals', slug: 'the-finals' },
  { name: 'Fall Guys', slug: 'fall-guys' },
  { name: 'Among Us', slug: 'among-us' },
  { name: 'EA Sports FC', slug: 'ea-sports-fc' },
] as const;

export const RANKS: readonly string[] = [
  'Wood',
  'Stone',
  'Iron',
  'Bronze',
  'Silver',
  'Gold',
  'Platinum',
  'Diamond',
  'Master',
  'Grandmaster',
  'Legend',
] as const;

/** ТЗ §47: only Monthly + SixMonths. No Annual / Lifetime / Trial. */
export const PREMIUM_PLANS = [
  { id: 'Monthly', months: 1 },
  { id: 'SixMonths', months: 6 },
] as const;

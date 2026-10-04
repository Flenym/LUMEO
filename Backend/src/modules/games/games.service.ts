import { BadRequestException, Injectable } from '@nestjs/common';

// Каталог игр Tier1 (19 официальных из Shared constants) + custom игры + режимы.
// TODO(db): SQL — таблицы games (unique slug), game_modes, user_games (favorite, main).

export const GAME_CATALOG = [
  'Fortnite',
  'Minecraft',
  'Valorant',
  'CS2',
  'Roblox',
  'Apex Legends',
  'Call of Duty',
  'GTA Online',
  'Rocket League',
  'Overwatch 2',
  'PUBG',
  'Terraria',
  'Sea of Thieves',
  'Rainbow Six Siege',
  'Destiny 2',
  'The Finals',
  'Fall Guys',
  'Among Us',
  'EA FC',
] as const;

export const GAME_MODES = [
  'Ranked',
  'Casual',
  'Creative',
  'Duo',
  'Trio',
  'Squad',
  'Custom',
] as const;

export type GameMode = (typeof GAME_MODES)[number] | string;

export interface CustomGame {
  id: string;
  name: string;
  slug: string;
  createdAt: string;
}

export interface UserGamePrefs {
  userId: string;
  favoriteGames: string[];
  mainGame: string | null;
  customModes: string[];
}

export function slugify(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/['"`]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

@Injectable()
export class GamesService {
  private customGames = new Map<string, CustomGame>(); // slug -> game
  private globalCustomModes = new Map<string, string>(); // lower(name) -> name
  private prefs = new Map<string, UserGamePrefs>();

  /** Официальные 19 (обратная совместимость — строковый массив). */
  catalog(): string[] {
    return [...GAME_CATALOG];
  }

  /** Полный каталог: официальные + custom + режимы. */
  catalogFull() {
    return {
      official: [...GAME_CATALOG],
      custom: [...this.customGames.values()],
      modes: [...GAME_MODES],
      customModes: [...this.globalCustomModes.values()],
      total: GAME_CATALOG.length + this.customGames.size,
    };
  }

  modes(): string[] {
    return [...GAME_MODES, ...this.globalCustomModes.values()];
  }

  addCustomMode(name: string): { name: string } {
    const clean = name.trim();
    if (!clean || clean.length > 48) {
      throw new BadRequestException({ code: 'INVALID_MODE', message: 'mode name 1..48 chars' });
    }
    if ((GAME_MODES as readonly string[]).map((m) => m.toLowerCase()).includes(clean.toLowerCase())) {
      throw new BadRequestException({ code: 'MODE_EXISTS', message: 'built-in mode already exists' });
    }
    if (this.globalCustomModes.has(clean.toLowerCase())) {
      throw new BadRequestException({ code: 'MODE_EXISTS', message: 'custom mode already exists' });
    }
    this.globalCustomModes.set(clean.toLowerCase(), clean);
    return { name: clean };
  }

  isKnownMode(mode: string): boolean {
    const l = mode.trim().toLowerCase();
    return (
      (GAME_MODES as readonly string[]).some((m) => m.toLowerCase() === l) || this.globalCustomModes.has(l)
    );
  }

  addCustom(name: string): CustomGame {
    const clean = name.trim();
    if (!clean || clean.length > 64) {
      throw new BadRequestException({ code: 'INVALID_GAME', message: 'game name 1..64 chars' });
    }
    const slug = slugify(clean);
    if (!slug) throw new BadRequestException({ code: 'INVALID_GAME', message: 'game name gives empty slug' });
    const officialSlugs = new Set([...GAME_CATALOG].map(slugify));
    if (officialSlugs.has(slug) || this.customGames.has(slug)) {
      throw new BadRequestException({ code: 'GAME_EXISTS', message: `game slug taken: ${slug}` });
    }
    const g: CustomGame = { id: `custom-${slug}`, name: clean, slug, createdAt: new Date().toISOString() };
    this.customGames.set(slug, g);
    return g;
  }

  isKnownGame(name: string): boolean {
    const slug = slugify(name);
    return [...GAME_CATALOG].some((g) => slugify(g) === slug) || this.customGames.has(slug);
  }

  private ensurePrefs(userId: string): UserGamePrefs {
    let p = this.prefs.get(userId);
    if (!p) {
      p = { userId, favoriteGames: [], mainGame: null, customModes: [] };
      this.prefs.set(userId, p);
    }
    return p;
  }

  setUserGames(userId: string, games: string[]) {
    const p = this.ensurePrefs(userId);
    for (const g of games) {
      if (!this.isKnownGame(g)) {
        throw new BadRequestException({ code: 'UNKNOWN_GAME', message: `unknown game: ${g}` });
      }
    }
    p.favoriteGames = [...new Set(games)];
    if (p.mainGame && !p.favoriteGames.includes(p.mainGame)) p.mainGame = null;
    return { userId, games: p.favoriteGames };
  }

  getUserGames(userId: string) {
    const p = this.ensurePrefs(userId);
    return { userId, games: p.favoriteGames, mainGame: p.mainGame, customModes: p.customModes };
  }

  setFavorites(userId: string, favoriteGames: string[], mainGame?: string | null) {
    const p = this.ensurePrefs(userId);
    for (const g of favoriteGames) {
      if (!this.isKnownGame(g)) {
        throw new BadRequestException({ code: 'UNKNOWN_GAME', message: `unknown game: ${g}` });
      }
    }
    p.favoriteGames = [...new Set(favoriteGames)];
    if (mainGame !== undefined) {
      if (mainGame !== null && !p.favoriteGames.includes(mainGame)) {
        throw new BadRequestException({ code: 'MAIN_NOT_FAVORITE', message: 'mainGame must be in favoriteGames' });
      }
      p.mainGame = mainGame;
    }
    return { userId, favoriteGames: p.favoriteGames, mainGame: p.mainGame };
  }

  setMainGame(userId: string, mainGame: string | null) {
    const p = this.ensurePrefs(userId);
    if (mainGame !== null && !p.favoriteGames.includes(mainGame)) {
      throw new BadRequestException({ code: 'MAIN_NOT_FAVORITE', message: 'mainGame must be in favoriteGames' });
    }
    p.mainGame = mainGame;
    return { userId, mainGame };
  }
}

import { Test } from '@nestjs/testing';
import { GamesService } from '../src/modules/games/games.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [GamesService] }).compile();
  return mod.get(GamesService);
}

describe('games Tier1', () => {
  test('каталог содержит 19 официальных игр', async () => {
    const g = await setup();
    expect(g.catalog()).toHaveLength(19);
    expect(g.catalog()).toContain('Fortnite');
    expect(g.catalogFull().total).toBe(19);
  });

  test('custom game: name+slug уникальны', async () => {
    const g = await setup();
    const c = g.addCustom('My Cool Game');
    expect(c.slug).toBe('my-cool-game');
    try {
      g.addCustom('My Cool Game');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'GAME_EXISTS' } });
    }
    // официальное имя в custom — тоже конфликт slug
    try {
      g.addCustom('Fortnite');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'GAME_EXISTS' } });
    }
  });

  test('modes: Ranked/Casual/Creative/Duo/Trio/Squad/Custom + custom mode', async () => {
    const g = await setup();
    for (const m of ['Ranked', 'Casual', 'Creative', 'Duo', 'Trio', 'Squad', 'Custom']) {
      expect(g.modes()).toContain(m);
    }
    expect(g.addCustomMode('Turbo')).toEqual({ name: 'Turbo' });
    expect(g.isKnownMode('turbo')).toBe(true);
    try {
      g.addCustomMode('Ranked');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'MODE_EXISTS' } });
    }
  });

  test('favoriteGames + mainGame; main обязан быть в избранном', async () => {
    const g = await setup();
    const r = g.setFavorites('u1', ['Fortnite', 'CS2'], 'CS2');
    expect(r).toMatchObject({ mainGame: 'CS2' });
    try {
      g.setMainGame('u1', 'Minecraft');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'MAIN_NOT_FAVORITE' } });
    }
    expect(g.getUserGames('u1').mainGame).toBe('CS2');
  });

  test('неизвестная игра в избранном отклоняется', async () => {
    const g = await setup();
    try {
      g.setFavorites('u1', ['No Such Game 123']);
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'UNKNOWN_GAME' } });
    }
  });
});

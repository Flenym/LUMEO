import { Test } from '@nestjs/testing';
import { StatusesService } from '../src/modules/statuses/statuses.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [StatusesService] }).compile();
  return mod.get(StatusesService);
}

describe('statuses Tier1', () => {
  test('set/get: цвета green/yellow/red + текст', async () => {
    const s = await setup();
    const r = s.set('u1', 'yellow', 'playing ranked');
    expect(r.color).toBe('yellow');
    expect(r.text).toBe('playing ranked');
    expect(s.get('u1').color).toBe('yellow');
  });

  test('emoji режутся по умолчанию, allowEmoji=true сохраняет', async () => {
    const s = await setup();
    const cut = s.set('u1', 'green', 'ready 🎮🔥 now');
    expect(cut.text).not.toMatch(/🎮/);
    expect(cut.text).toContain('ready');
    const kept = s.set('u2', 'green', 'ready 🎮 now', { allowEmoji: true });
    expect(kept.text).toContain('🎮');
  });

  test('текст длиннее 140 отклоняется', async () => {
    const s = await setup();
    try {
      s.set('u1', 'green', 'x'.repeat(141));
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'TEXT_TOO_LONG' } });
    }
  });

  test('moderation.isPublicTextAllowed режет запрещённое', async () => {
    const s = await setup();
    try {
      s.set('u1', 'red', 'contains spam-word-1 here', { bannedWords: ['spam-word-1'] });
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'MODERATION_REJECTED' } });
    }
  });

  test('таймер 15м → авто-возврат к prev/default', async () => {
    const s = await setup();
    const t0 = Date.now();
    s.set('u1', 'red', 'busy', { timer: '15m', defaultColor: 'green', defaultText: '' });
    // до истечения — статус на месте
    expect(s.get('u1', t0 + 14 * 60_000).color).toBe('red');
    // после — возврат к default (prev не было)
    const after = s.get('u1', t0 + 16 * 60_000);
    expect(after.color).toBe('green');
    expect(after.text).toBe('');
    expect(after.expiresAt).toBeNull();
  });

  test('inactive при lastSeen>5мин, текст не меняется', async () => {
    const s = await setup();
    s.set('u1', 'yellow', 'afk coffee');
    const t0 = Date.now();
    s.touchLastSeen('u1', 'exact', t0);
    const fresh = s.get('u1', t0 + 60_000);
    expect(fresh.inactive).toBe(false);
    expect(fresh.lastSeen).toContain('T'); // exact = ISO
    const stale = s.get('u1', t0 + 6 * 60_000);
    expect(stale.inactive).toBe(true);
    expect(stale.text).toBe('afk coffee'); // только флаг, текст цел
    // hidden режим скрывает lastSeen
    s.setLastSeenMode('u1', 'hidden');
    expect(s.get('u1', t0 + 60_000).lastSeen).toBeNull();
    // recent режим даёт корзину
    s.setLastSeenMode('u1', 'recent');
    expect(s.get('u1', t0 + 30_000).lastSeen).toBe('just_now');
  });
});

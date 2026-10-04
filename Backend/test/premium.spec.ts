import { Test } from '@nestjs/testing';
import { levelForXp, rankDisplay, rankForLevel, rankForXp, xpForEvent } from '../src/common/engines/xp.engine';
import { LevelsService } from '../src/modules/profiles/levels.service';
import { ProfilesService } from '../src/modules/profiles/profiles.service';
import { WalletService } from '../src/modules/wallet/wallet.service';

async function setup() {
  const mod = await Test.createTestingModule({
    providers: [LevelsService, ProfilesService, WalletService],
  }).compile();
  return {
    levels: mod.get(LevelsService),
    profiles: mod.get(ProfilesService),
    wallet: mod.get(WalletService),
  };
}

describe('premium + levels Tier2-4', () => {
  test('plans: Monthly/SixMonths ок; Annual/Lifetime/Trial запрещены', async () => {
    const { wallet } = await setup();
    expect(wallet.subscribe('u1', 'Monthly').plan).toBe('Monthly');
    expect(wallet.subscribe('u1', 'SixMonths').plan).toBe('SixMonths');
    expect(() => wallet.subscribe('u1', 'Annual')).toThrow();
    expect(() => wallet.subscribe('u1', 'Lifetime')).toThrow();
    expect(() => wallet.subscribe('u1', 'Free Trial')).toThrow();
    expect(wallet.premiumStatus('u1').active).toBe(true);
    expect(wallet.premiumStatus('nobody').active).toBe(false);
  });

  test('group premium: 3-5 участников, множитель xN', async () => {
    const { wallet } = await setup();
    expect(() => wallet.groupSubscribe('o', ['m1'], 'Monthly')).toThrow(); // 2 — мало
    expect(() => wallet.groupSubscribe('o', ['m1', 'm2', 'm3', 'm4', 'm5'], 'Monthly')).toThrow(); // 6 — много
    const g = wallet.groupSubscribe('o', ['m1', 'm2'], 'Monthly');
    expect(g.multiplier).toBe(3);
    expect(g.members).toHaveLength(3);
  });

  test('XP: таблица без фарма за сообщения; level/rank кривые', () => {
    expect(xpForEvent('session_complete')).toBe(50);
    expect(xpForEvent('message_sent')).toBe(0); // анти-спам
    expect(xpForEvent('unknown-event')).toBe(0);
    expect(levelForXp(0)).toBe(1);
    expect(levelForXp(100)).toBe(2);
    expect(rankForXp(0)).toBe('Wood');
    expect(rankForXp(18000)).toBe('Legend');
    expect(rankForLevel(30)).toBe('Legend');
    expect(rankDisplay(13)).toMatch(/^Gold (I|II|III)$/);
  });

  test('levels: daily cap 200 + auto-achievements', async () => {
    const { levels } = await setup();
    const day = '2026-10-04';
    // session_join=10: 30 ивентов = 300 base, но cap 200
    let last = null;
    for (let i = 0; i < 30; i++) last = levels.addXp('farmer', 'session_join', day);
    expect(last!.totalXp).toBeLessThanOrEqual(200);
    expect(last!.capped).toBe(true);
    // uncapped событие проходит полностью: base 50 + бонус ачивки 30
    const big = levels.addXp('farmer', 'session_complete', day);
    expect(big.base).toBe(50);
    expect(big.awarded).toBe(80);
    // auto-achievement за первую session_complete
    expect(big.achievements).toContain('first-session');
    const p = levels.getProgress('farmer');
    expect(p.level).toBeGreaterThanOrEqual(1);
    expect(typeof p.rank).toBe('string');
  });

  test('badges только через admin; sponsor — gradient', async () => {
    const { profiles } = await setup();
    expect(() =>
      profiles.awardBadge('u1', { code: 'x', title: 'X', category: 'social' }, { admin: false }),
    ).toThrow();
    const s = profiles.awardBadge(
      'u1',
      { code: 'sponsor-1', title: 'Sponsor', category: 'sponsor' },
      { admin: true },
    );
    expect(s.gradient).toBe(true);
    expect(profiles.listBadges('u1')).toHaveLength(1);
  });

  test('system blocks неудаляемы; feedback требует shared activity', async () => {
    const { profiles } = await setup();
    const sys = profiles.createBlock('u9', {
      type: 'identity',
      position: { x: 0, y: 0 },
      width: 12,
      height: 2,
      visibility: 'public',
    });
    expect(() => profiles.deleteBlock('u9', sys.id)).toThrow(/SYSTEM_BLOCK/);
    expect(() => profiles.giveFeedback('a', 'b', 'good')).toThrow();
    profiles.registerSharedActivity('a', 'b');
    const v = profiles.giveFeedback('a', 'b', 'good');
    expect(v.good).toBe(1);
    expect(() => profiles.giveFeedback('a', 'b', 'good')).toThrow(); // 1 голос/24ч
  });
});

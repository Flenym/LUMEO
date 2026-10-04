import { levelForXp, rankForLevel, xpForEvent } from '../src/common/engines/xp.engine';

describe('xp.engine', () => {
  test('xp table values', () => {
    expect(xpForEvent('session_complete')).toBe(50);
    expect(xpForEvent('session_join')).toBe(10);
    expect(xpForEvent('streak_day')).toBe(5);
    expect(xpForEvent('achievement')).toBe(30);
  });

  test('spam protection: message_sent gives 0', () => {
    expect(xpForEvent('message_sent')).toBe(0);
    expect(xpForEvent('unknown_event')).toBe(0);
  });

  test('level formula floor(sqrt(xp/100))+1', () => {
    expect(levelForXp(0)).toBe(1);
    expect(levelForXp(100)).toBe(2);
    expect(levelForXp(400)).toBe(3);
  });

  test('rank thresholds', () => {
    expect(rankForLevel(1)).toBe('Wood');
    expect(rankForLevel(5)).toBe('Bronze');
    expect(rankForLevel(10)).toBe('Silver');
    expect(rankForLevel(30)).toBe('Legend');
  });

  test('high levels are Legend', () => {
    expect(rankForLevel(99)).toBe('Legend');
  });
});

import { squadDayActivity, updateStreak } from '../src/common/engines/streak.engine';

describe('streak.engine', () => {
  test('first day starts streak', () => {
    expect(updateStreak(null, '2026-10-03')).toEqual({ streak: 1, broken: false });
  });

  test('consecutive day increments', () => {
    expect(updateStreak('2026-10-02', '2026-10-03', 3)).toEqual({ streak: 4, broken: false });
  });

  test('same day keeps streak', () => {
    expect(updateStreak('2026-10-03', '2026-10-03', 5)).toEqual({ streak: 5, broken: false });
  });

  test('gap breaks streak', () => {
    expect(updateStreak('2026-10-01', '2026-10-03', 5)).toEqual({ streak: 1, broken: true });
  });

  test('squadDayActivity needs joined session', () => {
    expect(squadDayActivity(true)).toBe(true);
    expect(squadDayActivity(false)).toBe(false);
  });
});

import { isInactive, isValidColor, normalizeStatus, resolveAfterExpiry, shouldAutoExpire } from '../src/common/engines/status.engine';

describe('status.engine', () => {
  test('normalize trims text and defaults color', () => {
    const s = normalizeStatus('bad', '  hi  ');
    expect(s.color).toBe('green');
    expect(s.text).toBe('hi');
    expect(s.updatedAt).toBeDefined();
  });

  test('isValidColor accepts only green|yellow|red', () => {
    expect(isValidColor('green')).toBe(true);
    expect(isValidColor('yellow')).toBe(true);
    expect(isValidColor('red')).toBe(true);
    expect(isValidColor('blue')).toBe(false);
  });

  test('shouldAutoExpire after 24h', () => {
    const now = Date.now();
    expect(shouldAutoExpire(now - 25 * 3600_000, now)).toBe(true);
    expect(shouldAutoExpire(now - 3600_000, now)).toBe(false);
  });

  test('resolveAfterExpiry resets to default', () => {
    const prev = normalizeStatus('red', 'busy');
    const next = resolveAfterExpiry(prev);
    expect(next.color).toBe('green');
  });

  test('isInactive after 5 min', () => {
    const now = Date.now();
    expect(isInactive(now - 6 * 60_000, now)).toBe(true);
    expect(isInactive(now - 60_000, now)).toBe(false);
  });
});

import { isPublicTextAllowed } from '../src/common/engines/moderation';

describe('moderation', () => {
  test('allows clean text', () => {
    expect(isPublicTextAllowed('hello world', ['bad'])).toEqual({ allowed: true });
  });

  test('blocks banned word (case-insensitive)', () => {
    const r = isPublicTextAllowed('Hello BAD thing', ['bad']);
    expect(r.allowed).toBe(false);
    expect(r.reason).toMatch(/banned_word/);
  });

  test('rejects empty text', () => {
    expect(isPublicTextAllowed('   ', []).allowed).toBe(false);
  });

  test('rejects too long text', () => {
    expect(isPublicTextAllowed('x'.repeat(5001), []).allowed).toBe(false);
  });
});

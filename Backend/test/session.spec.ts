import { canTransition, isReadyToStart, readyCount } from '../src/common/engines/session.engine';

describe('session.engine', () => {
  test('valid transitions', () => {
    expect(canTransition('Draft', 'Inviting')).toBe(true);
    expect(canTransition('Ready', 'Live')).toBe(true);
    expect(canTransition('Live', 'Paused')).toBe(true);
  });

  test('invalid transitions', () => {
    expect(canTransition('Draft', 'Live')).toBe(false);
    expect(canTransition('Finished', 'Live')).toBe(false);
    expect(canTransition('Live', 'Draft')).toBe(false);
  });

  test('readyCount counts ready+accepted', () => {
    const ps = [
      { userId: 'a', status: 'ready' },
      { userId: 'b', status: 'accepted' },
      { userId: 'c', status: 'pending' },
    ];
    expect(readyCount(ps)).toBe(2);
  });

  test('isReadyToStart respects minRequired', () => {
    const ps = [{ userId: 'a', status: 'ready' }];
    expect(isReadyToStart(ps, 2)).toBe(false);
    expect(isReadyToStart(ps, 1)).toBe(true);
  });

  test('cancel allowed from live states', () => {
    expect(canTransition('Paused', 'Cancelled')).toBe(true);
    expect(canTransition('Waiting', 'Cancelled')).toBe(true);
  });
});

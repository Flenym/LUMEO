import { canJoinSquad, canKick, hasRole } from '../src/common/engines/permissions.engine';

describe('permissions.engine', () => {
  test('role hierarchy', () => {
    expect(hasRole('Admin', 'Member')).toBe(true);
    expect(hasRole('Member', 'Admin')).toBe(false);
    expect(hasRole('Owner', 'Admin')).toBe(true);
  });

  test('kick rules', () => {
    expect(canKick('Admin', 'Member')).toBe(true);
    expect(canKick('Member', 'Admin')).toBe(false);
    expect(canKick('Admin', 'Owner')).toBe(false);
  });

  test('squad cap 200', () => {
    expect(canJoinSquad(199)).toBe(true);
    expect(canJoinSquad(200)).toBe(false);
  });
});

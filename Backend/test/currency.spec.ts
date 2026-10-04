import { applyTransaction } from '../src/common/engines/currency-ledger';

describe('currency-ledger', () => {
  test('applies credits', () => {
    const r = applyTransaction(100, [{ id: 'a', amount: 50 }]);
    expect(r.balance).toBe(150);
    expect(r.applied).toBe(1);
  });

  test('rejects zero amount', () => {
    expect(() => applyTransaction(0, [{ id: 'z', amount: 0 }])).toThrow();
  });

  test('rejects negative without override', () => {
    expect(() => applyTransaction(10, [{ id: 's', amount: -50 }])).toThrow(/insufficient/);
  });

  test('admin override allows negative', () => {
    const r = applyTransaction(10, [{ id: 's', amount: -50 }], { adminOverride: true });
    expect(r.balance).toBe(-40);
  });

  test('atomic: batch validated before apply', () => {
    expect(() =>
      applyTransaction(100, [
        { id: 'a', amount: 10 },
        { id: 'b', amount: 0 },
      ]),
    ).toThrow();
  });
});

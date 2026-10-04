import { Test } from '@nestjs/testing';
import {
  applyTransaction,
  applyTransactionOnce,
} from '../src/common/engines/currency-ledger';
import { WalletService } from '../src/modules/wallet/wallet.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [WalletService] }).compile();
  return mod.get(WalletService);
}

describe('currency ledger Tier2-4', () => {
  test('engine: amount 0 / нецелое отклоняется, всё-or-ничего', () => {
    expect(() => applyTransaction(0, [{ id: 'z', amount: 0 }])).toThrow();
    expect(() => applyTransaction(0, [{ id: 'f', amount: 1.5 }])).toThrow();
    expect(applyTransaction(10, [{ id: 'a', amount: 5 }]).balance).toBe(15);
  });

  test('engine: минус запрещён без admin override', () => {
    expect(() => applyTransaction(10, [{ id: 'm', amount: -20 }])).toThrow();
    expect(
      applyTransaction(10, [{ id: 'm', amount: -20 }], { adminOverride: true }).balance,
    ).toBe(-10);
  });

  test('engine: idempotency — дубли пропускаются', () => {
    const seen = new Set<string>();
    const r1 = applyTransactionOnce(0, [{ id: 'k1', amount: 100 }], seen);
    expect(r1.balance).toBe(100);
    expect(r1.skipped).toBe(0);
    const r2 = applyTransactionOnce(r1.balance, [{ id: 'k1', amount: 100 }], seen);
    expect(r2.balance).toBe(100);
    expect(r2.applied).toBe(0);
    expect(r2.skipped).toBe(1);
  });

  test('wallet: grant/transfer/balance только через ledger', async () => {
    const w = await setup();
    w.adminGrant('u1', 200, 'test grant');
    expect(w.balance('u1').balance).toBe(200);
    const t = w.transfer('u1', 'u2', 70, 'idem-1');
    expect(t).toMatchObject({ duplicate: false });
    expect(w.balance('u1').balance).toBe(130);
    expect(w.balance('u2').balance).toBe(70);
    // повтор с тем же idempotency-key — дубликат без движения
    const dup = w.transfer('u1', 'u2', 70, 'idem-1');
    expect(dup).toMatchObject({ duplicate: true });
    expect(w.balance('u1').balance).toBe(130);
    // недостаток средств
    expect(() => w.transfer('u2', 'u1', 1000)).toThrow();
    // история пишет from/to/amount/timestamp/status
    const h = w.history('u1');
    expect(h.length).toBeGreaterThan(0);
    for (const tx of h) {
      expect(tx).toMatchObject({ status: 'completed' });
      expect(typeof tx.timestamp).toBe('string');
    }
  });

  test('wallet: revoke через admin override + trade atomic', async () => {
    const w = await setup();
    w.adminGrant('rich', 100, 'seed');
    w.adminRevoke('rich', 150, 'penalty');
    expect(w.balance('rich').balance).toBe(-50);
    w.adminGrant('a', 100, 'seed');
    w.adminGrant('b', 100, 'seed');
    const tr = w.trade('a', 'b', 30, 40);
    expect(tr.out.amount).toBe(30);
    expect(tr.in.amount).toBe(40);
    expect(() => w.trade('a', 'b', 1000, 1)).toThrow();
  });

  test('wallet: кейсы — прозрачная очередь без рандома', async () => {
    const w = await setup();
    const table = w.rewardTable();
    expect(table.length).toBeGreaterThan(0);
    const first = w.openCase('opener', 'case-1');
    const second = w.openCase('opener', 'case-1');
    expect(first.reward.id).toBe(table[0].id);
    expect(second.reward.id).toBe(table[1 % table.length].id);
    expect(first.openIndex).toBe(0);
    expect(second.openIndex).toBe(1);
  });
});

// EMBER-ledger: баланс выводится ТОЛЬКО из транзакций.
// Никаких прямых UPDATE баланса — см. wallet.service и migrations CHECK (amount != 0).

export interface LedgerTx {
  id: string;
  /** Целое, != 0. Положительное — начисление, отрицательное — списание. */
  amount: number;
  reason?: string;
  actorRole?: 'user' | 'admin';
}

export interface LedgerResult {
  balance: number;
  applied: number;
}

/**
 * Атомарно применяет пачку транзакций к балансу.
 * - валидирует все tx до мутации (amount целое, != 0);
 * - запрещает уход в минус без adminOverride;
 * - возвращает новый баланс.
 */
export function applyTransaction(
  balance: number,
  txs: LedgerTx[],
  opts: { adminOverride?: boolean } = {},
): LedgerResult {
  if (!Number.isInteger(balance)) throw new Error('balance must be integer');
  let delta = 0;
  for (const tx of txs) {
    if (!Number.isInteger(tx.amount)) throw new Error(`tx ${tx.id}: amount must be integer`);
    if (tx.amount === 0) throw new Error(`tx ${tx.id}: amount must be != 0`);
    delta += tx.amount;
  }
  const next = balance + delta;
  if (next < 0 && !opts.adminOverride) {
    throw new Error('insufficient funds: negative balance requires admin override');
  }
  return { balance: next, applied: txs.length };
}

/**
 * Идемпотентное применение: транзакции, чьи id уже есть в seenIds,
 * пропускаются (повторный запрос с тем же idempotency-key не меняет баланс).
 * Возвращает новый баланс, число применённых и пропущенных (дубликатов).
 * Валидация/атомарность — как у applyTransaction (проверяются только новые tx).
 */
export function applyTransactionOnce(
  balance: number,
  txs: LedgerTx[],
  seenIds: Set<string> | string[],
  opts: { adminOverride?: boolean } = {},
): LedgerResult & { skipped: number } {
  const seen = seenIds instanceof Set ? seenIds : new Set(seenIds);
  const fresh = txs.filter((t) => !seen.has(t.id));
  if (fresh.length === 0) return { balance, applied: 0, skipped: txs.length };
  const res = applyTransaction(balance, fresh, opts);
  for (const t of fresh) seen.add(t.id);
  return { ...res, skipped: txs.length - fresh.length };
}

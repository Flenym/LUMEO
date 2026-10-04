import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { applyTransaction } from '../../common/engines/currency-ledger';

export type TxStatus = 'completed' | 'pending' | 'failed' | 'refunded';

export interface CurrencyTransaction {
  id: string;
  from: string;
  to: string;
  item?: string;
  amount: number;
  timestamp: string;
  status: TxStatus;
}

export type PremiumPlan = 'Monthly' | 'SixMonths';
export const PREMIUM_PLANS: PremiumPlan[] = ['Monthly', 'SixMonths'];
/** Annual/Lifetime/Trial запрещены — только Monthly/SixMonths. */
const PLAN_MONTHS: Record<PremiumPlan, number> = { Monthly: 1, SixMonths: 6 };

export interface RewardTableEntry {
  id: string;
  kind: 'ember' | 'item';
  amount: number;
  label: string;
}

/**
 * Прозрачная reward-таблица кейсов: без рандома-азарта, выдача строго
 * по очереди table[openIndex % len] (openIndex — счётчик открытий юзера).
 */
export const CASE_REWARD_TABLE: RewardTableEntry[] = [
  { id: 'ember-25', kind: 'ember', amount: 25, label: '25 EMBER' },
  { id: 'ember-50', kind: 'ember', amount: 50, label: '50 EMBER' },
  { id: 'sticker-pack', kind: 'item', amount: 0, label: 'Sticker Pack' },
  { id: 'ember-100', kind: 'ember', amount: 100, label: '100 EMBER' },
  { id: 'theme-cyan', kind: 'item', amount: 0, label: 'Cyan Theme' },
  { id: 'ember-10', kind: 'ember', amount: 10, label: '10 EMBER' },
];

export function currencyName(): string {
  return process.env.CURRENCY_NAME || 'EMBER';
}

// ВАЖНО: баланс только через ledger CurrencyTransaction. Прямых UPDATE нет.
// TODO: PostgreSQL CurrencyWallet + CurrencyTransaction (CHECK amount != 0).
@Injectable()
export class WalletService {
  private txs: CurrencyTransaction[] = [];
  private idempotency = new Map<string, unknown>();
  private redeemCodes = new Map<string, { amount: number; used: boolean }>();
  private caseOpens = new Map<string, number>(); // userId -> open count
  private premium = new Map<string, { plan: PremiumPlan; expiresAt: string }>();
  private groupPremium = new Map<string, { ownerId: string; members: string[]; plan: PremiumPlan; multiplier: number; expiresAt: string }>();

  assertCurrencyName(provided?: string): string {
    const name = currencyName();
    if (provided !== undefined && provided !== name) {
      throw new BadRequestException(`unknown currency: ${provided} (expected ${name})`);
    }
    return name;
  }

  /** Баланс — производное от ledger (сумма completed-транзакций). */
  balance(userId: string) {
    let b = 0;
    for (const t of this.txs) {
      if (t.status !== 'completed') continue;
      if (t.to === userId) b += t.amount;
      if (t.from === userId) b -= t.amount;
    }
    return { userId, currency: currencyName(), balance: b };
  }

  history(userId: string): CurrencyTransaction[] {
    return this.txs.filter((t) => t.from === userId || t.to === userId);
  }

  private append(tx: Omit<CurrencyTransaction, 'id' | 'timestamp' | 'status'> & Partial<Pick<CurrencyTransaction, 'id' | 'status'>>): CurrencyTransaction {
    const full: CurrencyTransaction = {
      id: tx.id ?? randomUUID(),
      from: tx.from,
      to: tx.to,
      amount: tx.amount,
      timestamp: new Date().toISOString(),
      status: tx.status ?? 'completed',
      ...(tx.item !== undefined ? { item: tx.item } : {}),
    };
    if (!Number.isInteger(full.amount) || full.amount === 0) {
      throw new BadRequestException(`tx amount must be integer != 0 (got ${full.amount})`);
    }
    this.txs.push(full);
    return full;
  }

  /** Grant — только admin (контроллер под AdminGuard; другой модуль вызывает сервис). */
  adminGrant(userId: string, amount: number, reason: string): CurrencyTransaction {
    if (!Number.isInteger(amount) || amount <= 0) throw new BadRequestException('grant amount must be positive integer');
    return this.append({ from: 'system', to: userId, amount, item: `grant:${reason}` });
  }

  /** Revoke — только admin, допускается уход через admin override. */
  adminRevoke(userId: string, amount: number, reason: string): CurrencyTransaction {
    if (!Number.isInteger(amount) || amount <= 0) throw new BadRequestException('revoke amount must be positive integer');
    const current = this.balance(userId).balance;
    // Атомарная проверка через engine (adminOverride=true разрешает отрицательный итог).
    applyTransaction(current, [{ id: randomUUID(), amount: -amount }], { adminOverride: true });
    return this.append({ from: userId, to: 'system', amount, item: `revoke:${reason}` });
  }

  /**
   * Transfer from→to, atomic: проверка баланса до записи, запрет отрицательного.
   * Idempotency-key: повтор с тем же ключом возвращает исходный результат.
   */
  transfer(from: string, to: string, amount: number, idempotencyKey?: string) {
    if (idempotencyKey && this.idempotency.has(idempotencyKey)) {
      return { ...(this.idempotency.get(idempotencyKey) as Record<string, unknown>), duplicate: true };
    }
    if (!from || !to || from === to) throw new BadRequestException('from/to must be different users');
    if (!Number.isInteger(amount) || amount <= 0) throw new BadRequestException('transfer amount must be positive integer');
    const current = this.balance(from).balance;
    applyTransaction(current, [{ id: randomUUID(), amount: -amount }]); // бросит при недостатке
    const tx = this.append({ from, to, amount });
    const result = { tx, fromBalance: this.balance(from).balance, toBalance: this.balance(to).balance, duplicate: false };
    if (idempotencyKey) this.idempotency.set(idempotencyKey, result);
    return result;
  }

  gift(from: string, to: string, amount: number, item?: string) {
    if (!Number.isInteger(amount) || amount <= 0) throw new BadRequestException('gift amount must be positive integer');
    const current = this.balance(from).balance;
    applyTransaction(current, [{ id: randomUUID(), amount: -amount }]);
    const tx = this.append({ from, to, amount, ...(item !== undefined ? { item } : {}) });
    return { tx };
  }

  createRedeemCode(code: string, amount: number) {
    if (!code || !Number.isInteger(amount) || amount <= 0) throw new BadRequestException('code and positive integer amount required');
    if (this.redeemCodes.has(code)) throw new BadRequestException('code already exists');
    this.redeemCodes.set(code, { amount, used: false });
    return { code, amount };
  }

  redeem(userId: string, code: string) {
    const entry = this.redeemCodes.get(code);
    if (!entry) throw new BadRequestException('unknown code');
    if (entry.used) throw new BadRequestException('code already redeemed');
    entry.used = true;
    const tx = this.append({ from: 'system', to: userId, amount: entry.amount, item: `redeem:${code}` });
    return { tx };
  }

  sell(userId: string, item: string, amount: number) {
    if (!item) throw new BadRequestException('item required');
    if (!Number.isInteger(amount) || amount <= 0) throw new BadRequestException('sell amount must be positive integer');
    const tx = this.append({ from: 'shop', to: userId, amount, item: `sell:${item}` });
    return { tx };
  }

  /**
   * Trade: атомарный обмен (две CurrencyTransaction, обе validating до записи).
   */
  trade(from: string, to: string, giveAmount: number, receiveAmount: number, giveItem?: string, receiveItem?: string) {
    if (from === to) throw new BadRequestException('from/to must differ');
    for (const a of [giveAmount, receiveAmount]) {
      if (!Number.isInteger(a) || a <= 0) throw new BadRequestException('trade amounts must be positive integers');
    }
    applyTransaction(this.balance(from).balance, [{ id: randomUUID(), amount: -giveAmount }]);
    applyTransaction(this.balance(to).balance, [{ id: randomUUID(), amount: -receiveAmount }]);
    const t1 = this.append({ from, to, amount: giveAmount, ...(giveItem !== undefined ? { item: giveItem } : {}) });
    const t2 = this.append({ from: to, to: from, amount: receiveAmount, ...(receiveItem !== undefined ? { item: receiveItem } : {}) });
    return { out: t1, in: t2 };
  }

  // ---------- Cases / drops ----------

  rewardTable(): RewardTableEntry[] {
    return [...CASE_REWARD_TABLE];
  }

  openCase(userId: string, caseId: string) {
    const idx = this.caseOpens.get(userId) ?? 0;
    const reward = CASE_REWARD_TABLE[idx % CASE_REWARD_TABLE.length];
    this.caseOpens.set(userId, idx + 1);
    let tx: CurrencyTransaction | null = null;
    if (reward.kind === 'ember') {
      tx = this.append({ from: 'system', to: userId, amount: reward.amount, item: `case:${caseId}:${reward.id}` });
    }
    return { userId, caseId, openIndex: idx, reward, tx };
  }

  // ---------- Premium ----------

  subscribe(userId: string, plan: string) {
    if (!PREMIUM_PLANS.includes(plan as PremiumPlan)) {
      throw new BadRequestException(`unknown plan: ${plan} (allowed: ${PREMIUM_PLANS.join(', ')}; no Annual/Lifetime/Trial)`);
    }
    const p = plan as PremiumPlan;
    const months = PLAN_MONTHS[p];
    const expiresAt = new Date(Date.now() + months * 30 * 24 * 3600_000).toISOString();
    this.premium.set(userId, { plan: p, expiresAt });
    return { userId, plan: p, expiresAt, active: true };
  }

  premiumStatus(userId: string) {
    const s = this.premium.get(userId);
    if (!s) return { userId, active: false };
    const active = Date.parse(s.expiresAt) > Date.now();
    return { userId, ...s, active };
  }

  /**
   * Group Premium: 3–5 участников суммарно (owner + members).
   * Множитель x3–x5 возвращается в DTO.
   */
  groupSubscribe(ownerId: string, memberIds: string[], plan: string) {
    if (!PREMIUM_PLANS.includes(plan as PremiumPlan)) {
      throw new BadRequestException(`unknown plan: ${plan} (allowed: ${PREMIUM_PLANS.join(', ')})`);
    }
    const members = [ownerId, ...memberIds.filter((m) => m !== ownerId)];
    if (members.length < 3 || members.length > 5) {
      throw new BadRequestException(`group premium requires 3-5 members total (got ${members.length})`);
    }
    const p = plan as PremiumPlan;
    const expiresAt = new Date(Date.now() + PLAN_MONTHS[p] * 30 * 24 * 3600_000).toISOString();
    const id = randomUUID();
    const group = { ownerId, members, plan: p, multiplier: members.length, expiresAt };
    this.groupPremium.set(id, group);
    for (const m of members) this.premium.set(m, { plan: p, expiresAt });
    return { id, ...group };
  }
}

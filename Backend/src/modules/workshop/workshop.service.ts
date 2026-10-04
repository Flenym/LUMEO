import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { paginate, Paginated } from '../../common/pagination';

export type WorkshopState = 'Draft' | 'Pending' | 'Approved' | 'Published' | 'Rejected';

export interface WorkshopItem {
  id: string;
  title: string;
  description: string;
  authorId: string;
  state: WorkshopState;
  /** Цена в EMBER. 0 = free. Платные требуют ≥5 approved free у автора. */
  price: number;
  official: boolean;
  version: number;
  purchases: number;
  rejectReason?: string;
  createdAt: string;
  updatedAt: string;
}

export interface WorkshopPurchaseTx {
  id: string;
  from: string;
  to: string;
  item: string;
  amount: number;
  timestamp: string;
  status: 'completed' | 'refunded';
}

/** Сколько approved free нужно автору перед платными публикациями. */
export const MIN_APPROVED_FREE_BEFORE_PAID = 5;

const FLOW: Record<WorkshopState, WorkshopState[]> = {
  Draft: ['Pending'],
  Pending: ['Approved', 'Rejected'],
  Approved: ['Published', 'Rejected'],
  Published: ['Pending'], // новая версия после publish — снова на модерацию
  Rejected: ['Draft'],
};

export type WorkshopFilter = 'All' | 'Free' | 'Paid' | 'Popular' | 'New' | 'Official';

// TODO: PostgreSQL WorkshopItem + WorkshopSubmission + WorkshopPurchase.
@Injectable()
export class WorkshopService {
  private items = new Map<string, WorkshopItem>();
  private purchases: WorkshopPurchaseTx[] = [];

  /** Счётчик approved free у автора (Approved или Published, price 0). */
  approvedFreeCount(authorId: string): number {
    let n = 0;
    for (const it of this.items.values()) {
      if (it.authorId === authorId && it.price === 0 && (it.state === 'Approved' || it.state === 'Published')) n++;
    }
    return n;
  }

  private assertPaidAllowed(authorId: string, price: number): void {
    if (price > 0 && this.approvedFreeCount(authorId) < MIN_APPROVED_FREE_BEFORE_PAID) {
      throw new ForbiddenException(
        `paid items require at least ${MIN_APPROVED_FREE_BEFORE_PAID} approved free items (creator has ${this.approvedFreeCount(authorId)})`,
      );
    }
  }

  create(title: string, authorId: string, opts: { price?: number; description?: string; official?: boolean } = {}) {
    if (!title || !title.trim()) throw new BadRequestException('title required');
    const price = opts.price ?? 0;
    if (!Number.isInteger(price) || price < 0) throw new BadRequestException('price must be a non-negative integer (EMBER)');
    this.assertPaidAllowed(authorId, price);
    const now = new Date().toISOString();
    const item: WorkshopItem = {
      id: randomUUID(),
      title: title.trim(),
      description: opts.description ?? '',
      authorId,
      state: 'Draft',
      price,
      official: opts.official ?? false,
      version: 1,
      purchases: 0,
      createdAt: now,
      updatedAt: now,
    };
    this.items.set(item.id, item);
    return item;
  }

  get(id: string): WorkshopItem {
    const item = this.items.get(id);
    if (!item) throw new BadRequestException('item not found');
    return item;
  }

  update(id: string, authorId: string, patch: { title?: string; description?: string; price?: number }) {
    const item = this.get(id);
    if (item.authorId !== authorId) throw new ForbiddenException('only author can edit');
    if (item.state !== 'Draft' && item.state !== 'Rejected') {
      throw new BadRequestException(`cannot edit item in state ${item.state}`);
    }
    if (patch.title !== undefined) {
      if (!patch.title.trim()) throw new BadRequestException('title required');
      item.title = patch.title.trim();
    }
    if (patch.description !== undefined) item.description = patch.description;
    if (patch.price !== undefined) {
      if (!Number.isInteger(patch.price) || patch.price < 0) throw new BadRequestException('price must be a non-negative integer (EMBER)');
      this.assertPaidAllowed(authorId, patch.price);
      item.price = patch.price;
    }
    item.updatedAt = new Date().toISOString();
    return item;
  }

  remove(id: string, authorId: string) {
    const item = this.get(id);
    if (item.authorId !== authorId) throw new ForbiddenException('only author can delete');
    if (item.state !== 'Draft' && item.state !== 'Rejected') {
      throw new BadRequestException(`cannot delete item in state ${item.state}`);
    }
    this.items.delete(id);
    return { deleted: id };
  }

  /** Переход по flow. Rejected требует reason. */
  transition(id: string, to: WorkshopState, reason?: string) {
    const item = this.get(id);
    if (!FLOW[item.state].includes(to)) throw new BadRequestException(`cannot ${item.state} -> ${to}`);
    if (to === 'Rejected' && (!reason || !reason.trim())) {
      throw new BadRequestException('rejection reason required');
    }
    if (to === 'Published') this.assertPaidAllowed(item.authorId, item.price);
    item.state = to;
    item.rejectReason = to === 'Rejected' ? reason!.trim() : undefined;
    item.updatedAt = new Date().toISOString();
    return item;
  }

  /** Submit на модерацию: Draft -> Pending. */
  submit(id: string) {
    return this.transition(id, 'Pending');
  }

  /** Решение модератора/админа: Pending|Approved -> Approved|Published|Rejected. */
  review(id: string, approve: boolean, reason?: string) {
    const item = this.get(id);
    if (item.state === 'Pending') return this.transition(id, approve ? 'Approved' : 'Rejected', reason);
    if (item.state === 'Approved' && approve) return this.transition(id, 'Published');
    if (item.state === 'Approved' && !approve) return this.transition(id, 'Rejected', reason);
    throw new BadRequestException(`cannot review item in state ${item.state}`);
  }

  /**
   * Новая версия после publish: версия +1 и снова в Pending (re-moderation).
   * Только из Published.
   */
  createVersion(id: string, authorId: string, patch: { title?: string; description?: string; price?: number } = {}) {
    const item = this.get(id);
    if (item.authorId !== authorId) throw new ForbiddenException('only author can version');
    if (item.state !== 'Published') throw new BadRequestException('versions can only be created from Published items');
    if (patch.title !== undefined) {
      if (!patch.title.trim()) throw new BadRequestException('title required');
      item.title = patch.title.trim();
    }
    if (patch.description !== undefined) item.description = patch.description;
    if (patch.price !== undefined) {
      if (!Number.isInteger(patch.price) || patch.price < 0) throw new BadRequestException('price must be a non-negative integer (EMBER)');
      this.assertPaidAllowed(authorId, patch.price);
      item.price = patch.price;
    }
    item.version += 1;
    item.state = 'Pending';
    item.updatedAt = new Date().toISOString();
    return item;
  }

  /**
   * Покупка: только Published. Платная пишет CurrencyTransaction
   * (from=buyer, to=author, amount=price); free — грант без движения валюты
   * (amount 0 запрещён CHECK-ограничением ledger).
   * Расчёт через wallet ledger выполняет вызывающий модуль.
   */
  purchase(itemId: string, buyerId: string) {
    const item = this.get(itemId);
    if (item.state !== 'Published') throw new BadRequestException('only Published items can be purchased');
    if (item.authorId === buyerId) throw new BadRequestException('author already owns the item');
    if (item.price === 0) {
      item.purchases += 1;
      return { item: item.id, buyer: buyerId, granted: true as const, tx: null as null };
    }
    const tx: WorkshopPurchaseTx = {
      id: randomUUID(),
      from: buyerId,
      to: item.authorId,
      item: item.id,
      amount: item.price,
      timestamp: new Date().toISOString(),
      status: 'completed',
    };
    this.purchases.push(tx);
    item.purchases += 1;
    return { item: item.id, buyer: buyerId, granted: true as const, tx };
  }

  /** Admin override цены (аудит — на стороне admin API). */
  setPriceAdmin(id: string, price: number) {
    const item = this.get(id);
    if (!Number.isInteger(price) || price < 0) throw new BadRequestException('price must be a non-negative integer (EMBER)');
    this.assertPaidAllowed(item.authorId, price);
    const old = item.price;
    item.price = price;
    item.updatedAt = new Date().toISOString();
    return { ...item, oldPrice: old };
  }

  purchaseHistory(itemId?: string): WorkshopPurchaseTx[] {
    return itemId ? this.purchases.filter((p) => p.item === itemId) : [...this.purchases];
  }

  /**
   * Preview без покупки: только safe-data (id/title/author/price/state/version
   * + короткий excerpt). Полный description/контент не отдаётся.
   */
  preview(id: string) {
    const item = this.get(id);
    const excerpt = item.description.slice(0, 280);
    return {
      id: item.id,
      title: item.title,
      authorId: item.authorId,
      price: item.price,
      free: item.price === 0,
      state: item.state,
      version: item.version,
      official: item.official,
      purchases: item.purchases,
      preview: { excerpt, hasMore: item.description.length > excerpt.length },
    };
  }

  list(filter: WorkshopFilter = 'All', page = 1, limit = 20, q?: string): Paginated<WorkshopItem> {
    let all = [...this.items.values()];
    if (q) {
      const needle = q.toLowerCase();
      all = all.filter((i) => i.title.toLowerCase().includes(needle));
    }
    switch (filter) {
      case 'Free':
        all = all.filter((i) => i.price === 0);
        break;
      case 'Paid':
        all = all.filter((i) => i.price > 0);
        break;
      case 'Popular':
        all = all.sort((a, b) => b.purchases - a.purchases);
        break;
      case 'New':
        all = all.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
        break;
      case 'Official':
        all = all.filter((i) => i.official);
        break;
      case 'All':
      default:
        break;
    }
    if (filter !== 'Popular' && filter !== 'New') {
      all = all.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
    }
    return paginate(all, page, limit);
  }
}

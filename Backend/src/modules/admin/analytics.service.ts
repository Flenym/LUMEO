import { Injectable } from '@nestjs/common';

export interface AnalyticsEvent {
  type: string;
  userId?: string;
  at?: string;
  data?: Record<string, unknown>;
}

/**
 * In-memory сбор событий для /admin/analytics.
 * Другие модули шлют события сюда (POST /admin/analytics/ingest).
 */
@Injectable()
export class AnalyticsService {
  private events: { type: string; userId?: string; at: number; data?: Record<string, unknown> }[] = [];
  private errors = 0;

  record(e: AnalyticsEvent) {
    const at = e.at ? Date.parse(e.at) : Date.now();
    this.events.push({ type: e.type, userId: e.userId, at: Number.isNaN(at) ? Date.now() : at, data: e.data });
    if (this.events.length > 20000) this.events.splice(0, this.events.length - 20000);
    return { recorded: true };
  }

  recordError() {
    this.errors += 1;
  }

  errorCount(): number {
    return this.errors;
  }

  private dayStr(ts: number): string {
    return new Date(ts).toISOString().slice(0, 10);
  }

  private activeOn(day: string): Set<string> {
    const s = new Set<string>();
    for (const e of this.events) {
      if (e.userId && this.dayStr(e.at) === day) s.add(e.userId);
    }
    return s;
  }

  summary(nowMs: number = Date.now()) {
    const today = this.dayStr(nowMs);
    const todayUsers = this.activeOn(today);
    const weekUsers = new Set<string>();
    for (let i = 0; i < 7; i++) {
      for (const u of this.activeOn(this.dayStr(nowMs - i * 86_400_000))) weekUsers.add(u);
    }
    const newUsers = this.events.filter((e) => e.type === 'user.register' && this.dayStr(e.at) === today).length;
    const invites = this.events.filter((e) => e.type === 'session.invite').length;
    const accepted = this.events.filter((e) => e.type === 'session.accepted').length;
    const messages = this.events.filter((e) => e.type === 'message.sent').length;
    const squads = this.events.filter((e) => e.type === 'squad.create').length;
    // Retention D1: активные сегодня из активных вчера / активные вчера.
    const yesterday = this.activeOn(this.dayStr(nowMs - 86_400_000));
    const retained = [...yesterday].filter((u) => todayUsers.has(u)).length;
    const widgetUsage: Record<string, number> = {};
    for (const e of this.events) {
      if (e.type === 'widget.use') {
        const w = String(e.data?.widget ?? 'unknown');
        widgetUsage[w] = (widgetUsage[w] ?? 0) + 1;
      }
    }
    return {
      dau: todayUsers.size,
      wau: weekUsers.size,
      newUsers,
      sessionsAcceptedRate: invites === 0 ? null : accepted / invites,
      sessions: { invites, accepted },
      messages,
      squads,
      retentionD1: yesterday.size === 0 ? null : retained / yesterday.size,
      widgetUsage,
    };
  }

  onlineCount(nowMs: number = Date.now(), windowMs = 5 * 60_000): number {
    const seen = new Set<string>();
    for (const e of this.events) {
      if (e.userId && nowMs - e.at <= windowMs && e.type !== 'user.register') seen.add(e.userId);
    }
    return seen.size;
  }
}

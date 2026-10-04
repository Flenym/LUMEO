import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { reportClusterId } from '../../common/engines/moderation';

export type ReportType = 'user' | 'profile' | 'status' | 'message' | 'workshop' | 'avatar' | 'group';

export const REPORT_TYPES: ReportType[] = ['user', 'profile', 'status', 'message', 'workshop', 'avatar', 'group'];

export interface Report {
  id: string;
  type: ReportType;
  targetId: string;
  reason: string;
  reporterId: string;
  clusterId: string;
  createdAt: string;
}

export interface ReportCluster {
  clusterId: string;
  type: ReportType;
  targetId: string;
  count: number;
  reasons: string[];
  reporterIds: string[];
  firstAt: string;
  lastAt: string;
  reports: Report[];
}

export interface ModerationAction {
  id: string;
  clusterId: string;
  action: string;
  moderatorId: string;
  createdAt: string;
}

// TODO: PostgreSQL Report + ModerationAction. Дедупликация по report_cluster_id.
@Injectable()
export class ReportsService {
  private clusters = new Map<string, ReportCluster>();
  private actions: ModerationAction[] = [];

  /**
   * Подача жалобы. clusterId = hash(type + targetId): повтор на ту же цель
   * добавляется к кластеру (count++), новый ряд не создаётся.
   */
  file(type: ReportType, targetId: string, reason: string, reporterId: string) {
    if (!REPORT_TYPES.includes(type)) throw new BadRequestException(`unknown report type: ${type}`);
    if (!targetId || !reason || !reporterId) throw new BadRequestException('type/targetId/reason/reporterId required');
    const clusterId = reportClusterId(type, targetId);
    const now = new Date().toISOString();
    const report: Report = { id: randomUUID(), type, targetId, reason, reporterId, clusterId, createdAt: now };
    const existing = this.clusters.get(clusterId);
    if (existing) {
      existing.count += 1;
      existing.lastAt = now;
      existing.reports.push(report);
      if (!existing.reasons.includes(reason)) existing.reasons.push(reason);
      if (!existing.reporterIds.includes(reporterId)) existing.reporterIds.push(reporterId);
      return { ...report, duplicate: true, count: existing.count };
    }
    const cluster: ReportCluster = {
      clusterId,
      type,
      targetId,
      count: 1,
      reasons: [reason],
      reporterIds: [reporterId],
      firstAt: now,
      lastAt: now,
      reports: [report],
    };
    this.clusters.set(clusterId, cluster);
    return { ...report, duplicate: false, count: 1 };
  }

  /** GET /reports?clustered=true — кластеры (count desc); иначе плоский список. */
  list(clustered = false): ReportCluster[] | Report[] {
    const clusters = [...this.clusters.values()].sort((a, b) => b.count - a.count || (a.firstAt < b.firstAt ? -1 : 1));
    if (clustered) return clusters;
    return clusters.flatMap((c) => c.reports);
  }

  getCluster(clusterId: string): ReportCluster {
    const c = this.clusters.get(clusterId);
    if (!c) throw new BadRequestException('cluster not found');
    return c;
  }

  moderate(clusterId: string, action: string, moderatorId: string) {
    this.getCluster(clusterId); // 400 если нет
    if (!action || !moderatorId) throw new BadRequestException('action/moderatorId required');
    const a: ModerationAction = {
      id: randomUUID(),
      clusterId,
      action,
      moderatorId,
      createdAt: new Date().toISOString(),
    };
    this.actions.push(a);
    return a;
  }

  moderationLog(): ModerationAction[] {
    return [...this.actions];
  }

  clusterCount(): number {
    return this.clusters.size;
  }

  totalReports(): number {
    let n = 0;
    for (const c of this.clusters.values()) n += c.count;
    return n;
  }
}

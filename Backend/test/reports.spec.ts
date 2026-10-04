import { Test } from '@nestjs/testing';
import { assertNoPlaintext, reportClusterId } from '../src/common/engines/moderation';
import { ReportsService } from '../src/modules/reports/reports.service';

async function setup() {
  const mod = await Test.createTestingModule({ providers: [ReportsService] }).compile();
  return mod.get(ReportsService);
}

describe('reports Tier2-4', () => {
  test('дедуплика: повтор на ту же цель — тот же clusterId, count++', async () => {
    const r = await setup();
    const first = r.file('status', 'target-1', 'spam', 'reporter-a');
    expect(first.duplicate).toBe(false);
    expect(first.count).toBe(1);
    const second = r.file('status', 'target-1', 'abuse', 'reporter-b');
    expect(second.duplicate).toBe(true);
    expect(second.clusterId).toBe(first.clusterId);
    expect(second.count).toBe(2);
    expect(r.clusterCount()).toBe(1);
    expect(r.totalReports()).toBe(2);
  });

  test('разные цели/типы — разные кластеры; list clustered', async () => {
    const r = await setup();
    r.file('user', 'u-1', 'spam', 'rep-1');
    r.file('profile', 'u-1', 'spam', 'rep-1'); // другой тип — другой кластер
    r.file('user', 'u-2', 'spam', 'rep-1');
    expect(r.clusterCount()).toBe(3);
    const clusters = r.list(true);
    expect(Array.isArray(clusters)).toBe(true);
    expect(clusters).toHaveLength(3);
    const flat = r.list(false);
    expect(flat).toHaveLength(3);
  });

  test('moderate пишет audit-лог; неизвестный тип отклоняется', async () => {
    const r = await setup();
    expect(() => r.file('nope' as never, 't', 'x', 'rep')).toThrow();
    const f = r.file('message', 'm-1', 'harassment', 'rep-1');
    const a = r.moderate(f.clusterId, 'mute-user', 'mod-1');
    expect(a.clusterId).toBe(f.clusterId);
    expect(r.moderationLog()).toHaveLength(1);
  });

  test('clusterId детерминирован: hash(type + targetId)', () => {
    expect(reportClusterId('user', 'u-1')).toBe(reportClusterId('user', 'u-1'));
    expect(reportClusterId('user', 'u-1')).not.toBe(reportClusterId('user', 'u-2'));
    expect(reportClusterId('user', 'u-1')).not.toBe(reportClusterId('profile', 'u-1'));
  });

  test('E2EE: plaintext body запрещён, пустой — ок', () => {
    expect(() => assertNoPlaintext('hello')).toThrow(/USE_E2EE/);
    expect(() => assertNoPlaintext({ text: 'hi' })).toThrow(/USE_E2EE/);
    expect(() => assertNoPlaintext(undefined)).not.toThrow();
    expect(() => assertNoPlaintext(null)).not.toThrow();
    expect(() => assertNoPlaintext('')).not.toThrow();
  });
});

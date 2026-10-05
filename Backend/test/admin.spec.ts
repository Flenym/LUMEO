import { ForbiddenException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from '../src/modules/admin/admin.service';
import { AnalyticsService } from '../src/modules/admin/analytics.service';
import { NotificationsModule } from '../src/modules/notifications/notifications.module';
import { LevelsService } from '../src/modules/profiles/levels.service';
import { ProfilesModule } from '../src/modules/profiles/profiles.module';
import { ProfilesService } from '../src/modules/profiles/profiles.service';
import { ReportsModule } from '../src/modules/reports/reports.module';
import { WalletService } from '../src/modules/wallet/wallet.service';
import { WalletModule } from '../src/modules/wallet/wallet.module';
import { WorkshopModule } from '../src/modules/workshop/workshop.module';

/**
 * AdminService через @nestjs/testing. Модуль собран зеркально admin.module:
 * все зависимости AdminService (ProfilesService, LevelsService, WalletService,
 * WorkshopService, ReportsService, NotificationsService, AnalyticsService)
 * резолвятся через импорты фича-модулей + прямые провайдеры.
 */
async function setup() {
  const mod = await Test.createTestingModule({
    imports: [ProfilesModule, WalletModule, WorkshopModule, ReportsModule, NotificationsModule],
    providers: [AdminService, AnalyticsService],
  }).compile();
  const admin = mod.get(AdminService);
  const profiles = mod.get(ProfilesService);
  const levels = mod.get(LevelsService);
  const wallet = mod.get(WalletService);
  // Чистим PUBLIC_RELEASE чтобы тесты были детерминированы независимо от окружения.
  delete process.env.PUBLIC_RELEASE;
  return { mod, admin, profiles, levels, wallet };
}

describe('admin service', () => {
  test('ban/unban flips state + audit entries', async () => {
    const { mod, admin } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      expect(admin.ban('adm', 'u1', 'spam')).toEqual({ userId: 'u1', banned: true });
      expect(admin.usersSearch('alice')[0].banned).toBe(true);
      expect(admin.unban('adm', 'u1')).toEqual({ userId: 'u1', banned: false });
      expect(admin.usersSearch('alice')[0].banned).toBe(false);
      const actions = admin.auditLog().map((e) => e.action);
      expect(actions).toContain('user.ban');
      expect(actions).toContain('user.unban');
      const banEntry = admin.auditLog().find((e) => e.action === 'user.ban');
      expect(banEntry).toMatchObject({ admin: 'adm', target: 'u1', reason: 'spam' });
    } finally {
      await mod.close();
    }
  });

  test('mute/unmute flips state + audit entries', async () => {
    const { mod, admin } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      expect(admin.mute('adm', 'u1')).toEqual({ userId: 'u1', muted: true });
      expect(admin.usersSearch()[0].muted).toBe(true);
      expect(admin.unmute('adm', 'u1')).toEqual({ userId: 'u1', muted: false });
      const actions = admin.auditLog().map((e) => e.action);
      expect(actions).toContain('user.mute');
      expect(actions).toContain('user.unmute');
    } finally {
      await mod.close();
    }
  });

  test('verify adds kind + audit entry', async () => {
    const { mod, admin } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      const r = admin.verify('adm', 'u1', 'Verified', 'manual check');
      expect(r).toEqual({ userId: 'u1', verified: ['Verified'] });
      const entry = admin.auditLog().find((e) => e.action === 'user.verify');
      expect(entry).toMatchObject({ admin: 'adm', target: 'u1' });
      expect(entry?.new).toEqual({ verified: ['Verified'] });
    } finally {
      await mod.close();
    }
  });

  test('verify rejects unknown kind', async () => {
    const { mod, admin } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      expect(() => admin.verify('adm', 'u1', 'Nope')).toThrow(/kind must be one of/);
    } finally {
      await mod.close();
    }
  });

  test('grant credits wallet + xp + audit', async () => {
    const { mod, admin, wallet, levels } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      const r = admin.grant('adm', 'u1', 100, 50, 'compensation');
      expect(r.tx).toBeDefined();
      expect(r.xpRes?.totalXp).toBe(50);
      expect(wallet.balance('u1').balance).toBe(100);
      expect(levels.getProgress('u1').totalXp).toBe(50);
      const entry = admin.auditLog().find((e) => e.action === 'economy.grant');
      expect(entry).toMatchObject({ admin: 'adm', target: 'u1', reason: 'compensation' });
    } finally {
      await mod.close();
    }
  });

  test('revoke reduces balance/xp + audit', async () => {
    const { mod, admin, wallet, levels } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      admin.grant('adm', 'u1', 100, 50);
      const r = admin.revoke('adm', 'u1', 30, 20, 'abuse');
      expect(r.tx).toBeDefined();
      expect(wallet.balance('u1').balance).toBe(70);
      expect(levels.getProgress('u1').totalXp).toBe(30);
      expect(admin.auditLog().map((e) => e.action)).toContain('economy.revoke');
    } finally {
      await mod.close();
    }
  });

  test('BetaTester closed when PUBLIC_RELEASE=true (verify/betaAward/decide)', async () => {
    const { mod, admin, profiles } = await setup();
    const prev = process.env.PUBLIC_RELEASE;
    process.env.PUBLIC_RELEASE = 'true';
    try {
      admin.registerUser('u1', 'alice');
      expect(() => admin.verify('adm', 'u1', 'BetaTester')).toThrow(ForbiddenException);
      expect(() => admin.betaAward('adm', 'u1')).toThrow(ForbiddenException);
      const req = profiles.requestVerification('u1', 'BetaTester');
      expect(() => admin.verificationDecide('adm', 'u1', req.id, true)).toThrow(ForbiddenException);
      // reject при этом разрешён — закрыта только выдача
      const rejected = admin.verificationDecide('adm', 'u1', req.id, false, 'closed');
      expect(rejected.status).toBe('rejected');
    } finally {
      if (prev === undefined) delete process.env.PUBLIC_RELEASE;
      else process.env.PUBLIC_RELEASE = prev;
      await mod.close();
    }
  });

  test('betaAward happy path + betaList', async () => {
    const { mod, admin } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      admin.registerUser('u2', 'bob');
      const r = admin.betaAward('adm', 'u1', 'early tester');
      expect(r.verified).toContain('BetaTester');
      const beta = admin.betaList('adm');
      expect(beta.map((u) => u.id)).toEqual(['u1']);
    } finally {
      await mod.close();
    }
  });

  test('verification decide approve syncs verified + list filter', async () => {
    const { mod, admin, profiles } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      const req = profiles.requestVerification('u1', 'Verified');
      const decided = admin.verificationDecide('adm', 'u1', req.id, true);
      expect(decided.status).toBe('approved');
      expect(admin.usersSearch('alice')[0].verified).toContain('Verified');
      expect(admin.verificationList('adm').length).toBe(1);
      expect(admin.verificationList('adm', 'approved').length).toBe(1);
      expect(admin.verificationList('adm', 'pending').length).toBe(0);
      expect(admin.auditLog().map((e) => e.action)).toContain('verification.approve');
    } finally {
      await mod.close();
    }
  });

  test('verification decide unknown request throws', async () => {
    const { mod, admin } = await setup();
    try {
      admin.registerUser('u1', 'alice');
      expect(() => admin.verificationDecide('adm', 'u1', 'nope', true)).toThrow(/not found/);
    } finally {
      await mod.close();
    }
  });

  test('flags set/list + audit entry', async () => {
    const { mod, admin } = await setup();
    try {
      expect(admin.flagsList().workshop_enabled).toBe(true);
      expect(admin.setFlag('adm', 'workshop_enabled', false)).toEqual({
        key: 'workshop_enabled',
        enabled: false,
      });
      expect(admin.flagsList().workshop_enabled).toBe(false);
      const entry = admin.auditLog().find((e) => e.action === 'flag.set');
      expect(entry).toMatchObject({ admin: 'adm', target: 'workshop_enabled' });
    } finally {
      await mod.close();
    }
  });

  test('audit log accumulates entries for every action', async () => {
    const { mod, admin } = await setup();
    try {
      expect(admin.auditLog()).toEqual([]);
      admin.registerUser('u1', 'alice');
      admin.ban('adm', 'u1');
      admin.grant('adm', 'u1', 10, 10);
      admin.setFlag('adm', 'gifts_enabled', false);
      const actions = admin.auditLog().map((e) => e.action);
      expect(actions).toEqual(['user.ban', 'economy.grant', 'flag.set']);
      for (const e of admin.auditLog()) {
        expect(typeof e.timestamp).toBe('string');
        expect(e.admin).toBe('adm');
      }
    } finally {
      await mod.close();
    }
  });
});

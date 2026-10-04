import { Test } from '@nestjs/testing';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { AuthService } from '../src/modules/auth/auth.service';

async function setup() {
  const mod = await Test.createTestingModule({
    imports: [JwtModule.register({})],
    providers: [AuthService],
  }).compile();
  return { auth: mod.get(AuthService), jwt: mod.get(JwtService) };
}

describe('auth Tier1', () => {
  test('register ok, @username нормализуется', async () => {
    const { auth } = await setup();
    const u = await auth.register('Test@Example.com', '@hero_01', 'secret123');
    expect(u.email).toBe('test@example.com');
    expect(u.username).toBe('@hero_01');
  });

  test('duplicate username запрещён', async () => {
    const { auth } = await setup();
    await auth.register('a@x.io', 'dupe_user', 'secret123');
    await expect(auth.register('b@x.io', '@dupe_user', 'secret123')).rejects.toMatchObject({
      response: { code: 'USERNAME_TAKEN' },
    });
  });

  test('duplicate email запрещён', async () => {
    const { auth } = await setup();
    await auth.register('same@x.io', 'user_one1', 'secret123');
    await expect(auth.register('SAME@x.io', 'user_two2', 'secret123')).rejects.toMatchObject({
      response: { code: 'EMAIL_TAKEN' },
    });
  });

  test('invalid username отклоняется', async () => {
    const { auth } = await setup();
    await expect(auth.register('c@x.io', 'ab', 'secret123')).rejects.toMatchObject({
      response: { code: 'INVALID_USERNAME' },
    });
    await expect(auth.register('c@x.io', 'bad!name', 'secret123')).rejects.toMatchObject({
      response: { code: 'INVALID_USERNAME' },
    });
  });

  test('verify code cooldown 60с', async () => {
    const { auth } = await setup();
    await auth.register('v@x.io', 'verify_me', 'secret123');
    const first = auth.requestVerifyCode('v@x.io');
    expect(first.cooldownSec).toBe(60);
    expect(() => auth.requestVerifyCode('v@x.io')).toThrow();
    try {
      auth.requestVerifyCode('v@x.io');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'VERIFY_COOLDOWN' } });
    }
  });

  test('verify email: wrong code, success, TTL 10 мин', async () => {
    const { auth } = await setup();
    await auth.register('w@x.io', 'verify_two', 'secret123');
    auth.requestVerifyCode('w@x.io');
    // verifyEmail синхронный — sync-throw, не rejects
    try {
      auth.verifyEmail('w@x.io', '000000');
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'CODE_MISMATCH' } });
    }
    const code = auth.peekVerifyCode('w@x.io');
    expect(code).toMatch(/^\d{6}$/);
    expect(auth.verifyEmail('w@x.io', code as string)).toEqual({ verified: true });
    expect(auth.getUserById).toBeDefined();
    // повтор — код уже consumed
    try {
      auth.verifyEmail('w@x.io', code as string);
      fail('must throw');
    } catch (e) {
      expect(e).toMatchObject({ response: { code: 'NO_CODE' } });
    }

    // TTL: код протухает через 10 мин
    await auth.register('t@x.io', 'verify_ttl', 'secret123');
    auth.requestVerifyCode('t@x.io');
    const realNow = Date.now;
    try {
      Date.now = () => realNow() + 11 * 60_000;
      try {
        auth.verifyEmail('t@x.io', auth.peekVerifyCode('t@x.io') as string);
        fail('must throw');
      } catch (e) {
        expect(e).toMatchObject({ response: { code: 'CODE_EXPIRED' } });
      }
    } finally {
      Date.now = realNow;
    }
  });

  test('login ok + validateAccess', async () => {
    const { auth, jwt } = await setup();
    const u = await auth.register('l@x.io', 'login_user', 'secret123');
    const pair = await auth.login('login_user', 'secret123', jwt, '10.0.0.1');
    expect(pair.accessToken).toBeDefined();
    expect(pair.refreshToken).toBeDefined();
    await expect(auth.validateAccess(pair.accessToken, jwt)).resolves.toBe(u.id);
    // login по email тоже работает
    const pair2 = await auth.login('L@x.io', 'secret123', jwt, '10.0.0.2');
    expect(pair2.userId).toBe(u.id);
  });

  test('brute-force lockout: 5 неудач = 15 мин', async () => {
    const { auth, jwt } = await setup();
    await auth.register('k@x.io', 'lock_user', 'secret123');
    for (let i = 0; i < 5; i++) {
      await expect(auth.login('lock_user', 'wrong', jwt, `10.0.1.${i}`)).rejects.toMatchObject({
        response: { code: 'INVALID_CREDENTIALS' },
      });
    }
    // 6-я попытка даже с верным паролем — LOCKED_OUT
    await expect(auth.login('lock_user', 'secret123', jwt, '10.0.1.99')).rejects.toMatchObject({
      response: { code: 'LOCKED_OUT' },
    });
  });

  test('rate-limit login 5/мин/IP', async () => {
    const { auth, jwt } = await setup();
    await auth.register('r@x.io', 'rate_user', 'secret123');
    for (let i = 0; i < 5; i++) {
      await auth.login('rate_user', 'secret123', jwt, '10.0.2.1', `dev-${i}`);
    }
    await expect(auth.login('rate_user', 'secret123', jwt, '10.0.2.1', 'dev-x')).rejects.toMatchObject({
      response: { code: 'TOO_MANY_REQUESTS' },
    });
  });

  test('refresh rotation + blacklist + logout + logout-all', async () => {
    const { auth, jwt } = await setup();
    const u = await auth.register('f@x.io', 'refresh_user', 'secret123');
    const pair = await auth.login('refresh_user', 'secret123', jwt, '10.0.3.1');
    const rotated = await auth.refresh(pair.refreshToken, jwt);
    expect(rotated.accessToken).not.toBe(pair.accessToken);
    // старый refresh отозван
    await expect(auth.refresh(pair.refreshToken, jwt)).rejects.toMatchObject({
      response: { code: 'TOKEN_REVOKED' },
    });
    expect(auth.isBlacklisted(pair.refreshToken)).toBe(true);

    // logout одной сессии
    await auth.logout(rotated.refreshToken);
    await expect(auth.refresh(rotated.refreshToken, jwt)).rejects.toThrow();

    // две сессии + logout-all
    const p1 = await auth.login('refresh_user', 'secret123', jwt, '10.0.3.2', 'dev-a');
    void p1;
    await auth.login('refresh_user', 'secret123', jwt, '10.0.3.3', 'dev-b');
    expect(auth.listSessions(u.id).length).toBe(2);
    const out = await auth.logoutAll(u.id);
    expect(out.revokedSessions).toBe(2);
    expect(auth.listSessions(u.id)).toEqual([]);
    // access из logout-all тоже в blacklist
    expect(auth.isBlacklisted(p1.accessToken)).toBe(true);
  });
});

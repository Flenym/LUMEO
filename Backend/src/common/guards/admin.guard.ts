import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { isDeviceRegistered } from '../../modules/admin/admin-devices';

// Отдельный auth layer для Admin API:
// 1) заголовок X-Admin-Token, ИЛИ
// 2) JWT (HS256, JWT_SECRET) с role=admin + pre-registered deviceId.
// Без DI-зависимостей — guard используется и вне AdminModule (wallet grant).
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const token = req.headers?.['x-admin-token'];
    const expected = process.env.ADMIN_TOKEN || 'dev-admin-token';
    if (token && token === expected) {
      req.admin = { via: 'token' };
      return true;
    }
    const auth: string = req.headers?.['authorization'] || '';
    const m = /^Bearer (.+)$/.exec(auth);
    if (m && verifyAdminJwt(m[1])) {
      const payload = JSON.parse(Buffer.from(m[1].split('.')[1], 'base64url').toString('utf8'));
      req.admin = { via: 'jwt', sub: payload.sub, deviceId: payload.deviceId };
      return true;
    }
    throw new UnauthorizedException('Admin auth required (X-Admin-Token or admin JWT + registered device)');
  }
}

function verifyAdminJwt(token: string): boolean {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;
    const secret = process.env.JWT_SECRET || 'dev-only-change-me';
    const data = `${parts[0]}.${parts[1]}`;
    const expected = createHmac('sha256', secret).update(data).digest();
    const actual = Buffer.from(parts[2].replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return false;
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (payload.role !== 'admin') return false;
    if (payload.exp && Date.now() / 1000 > Number(payload.exp)) return false;
    return isDeviceRegistered(payload.deviceId);
  } catch {
    return false;
  }
}

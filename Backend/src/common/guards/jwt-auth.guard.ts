import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

// Базовый JWT guard для пользовательских роутов. Токен: Authorization: Bearer <access>.
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    // Публичные роуты auth/health пропускаются на уровне контроллеров.
    const header: string = req.headers?.authorization ?? '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) throw new UnauthorizedException('Missing bearer token');
    try {
      req.user = await this.jwt.verifyAsync(token, {
        secret: process.env.JWT_SECRET || 'dev-only-change-me',
      });
      return true;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}

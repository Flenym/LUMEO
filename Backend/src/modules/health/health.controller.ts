import { Controller, Get } from '@nestjs/common';
import { WsRegistry } from '../../common/ws-registry';

const APP_VERSION = '0.1.0';

// GET /health (вне /api/v1 префикса — см. main.ts exclude)
@Controller('health')
export class HealthController {
  @Get()
  check() {
    const db = process.env.DATABASE_URL ? 'configured' : 'degraded';
    return {
      status: 'ok',
      version: APP_VERSION,
      uptime: Math.floor(process.uptime()),
      wsConnections: WsRegistry.count(),
      ws: '/ws',
      db,
    };
  }
}

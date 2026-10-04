import { Controller, Get } from '@nestjs/common';

// GET /api/v1/version (под глобальным префиксом — см. main.ts).
@Controller('version')
export class VersionController {
  @Get()
  version() {
    return { version: '0.1.0', api: 'v1', tier: 'tier1' };
  }
}

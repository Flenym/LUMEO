import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ReportsService, ReportType } from './reports.service';

@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Post()
  file(@Body() dto: { type: ReportType; targetId: string; reason: string; reporterId: string }) {
    return this.reports.file(dto.type, dto.targetId, dto.reason, dto.reporterId);
  }

  @Get()
  list(@Query('clustered') clustered?: string) {
    return this.reports.list(clustered === 'true');
  }

  @Get('clusters/:clusterId')
  cluster(@Param('clusterId') clusterId: string) {
    return this.reports.getCluster(clusterId);
  }
}

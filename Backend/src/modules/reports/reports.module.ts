import { Module } from '@nestjs/common';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';
import { MessagesController } from './messages.controller';
import { E2eeService } from './e2ee.service';

@Module({
  controllers: [ReportsController, MessagesController],
  providers: [ReportsService, E2eeService],
  exports: [ReportsService, E2eeService],
})
export class ReportsModule {}

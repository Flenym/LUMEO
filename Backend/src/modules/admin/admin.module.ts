import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AnalyticsService } from './analytics.service';
import { AdminGuard } from '../../common/guards/admin.guard';
import { ProfilesModule } from '../profiles/profiles.module';
import { WalletModule } from '../wallet/wallet.module';
import { WorkshopModule } from '../workshop/workshop.module';
import { ReportsModule } from '../reports/reports.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [JwtModule.register({}), ProfilesModule, WalletModule, WorkshopModule, ReportsModule, NotificationsModule],
  controllers: [AdminController],
  providers: [AdminService, AnalyticsService, AdminGuard],
  exports: [AdminService, AnalyticsService],
})
export class AdminModule {}

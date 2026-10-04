import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './modules/health/health.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { FriendsModule } from './modules/friends/friends.module';
import { StatusesModule } from './modules/statuses/statuses.module';
import { GamesModule } from './modules/games/games.module';
import { SessionsModule } from './modules/sessions/sessions.module';
import { SquadsModule } from './modules/squads/squads.module';
import { ProfilesModule } from './modules/profiles/profiles.module';
import { WorkshopModule } from './modules/workshop/workshop.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ReportsModule } from './modules/reports/reports.module';
import { AdminModule } from './modules/admin/admin.module';
import { RealtimeModule } from './modules/realtime/realtime.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    HealthModule,
    AuthModule,
    UsersModule,
    FriendsModule,
    StatusesModule,
    GamesModule,
    SessionsModule,
    SquadsModule,
    ProfilesModule,
    WorkshopModule,
    WalletModule,
    NotificationsModule,
    ReportsModule,
    AdminModule,
    RealtimeModule,
  ],
})
export class AppModule {}

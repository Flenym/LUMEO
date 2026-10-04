import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { NotificationsService, NotificationStatus, NotificationType } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  /** Внутренняя отправка (вызывается другими модулями). */
  @Post('send')
  send(@Body() dto: { userId: string; type: NotificationType; payload?: Record<string, unknown> }) {
    return this.notifications.send(dto.userId, dto.type, dto.payload ?? {});
  }

  @Get('mine/:userId')
  mine(
    @Param('userId') userId: string,
    @Query('type') type?: NotificationType,
    @Query('read') read?: string,
    @Query('status') status?: NotificationStatus,
  ) {
    return this.notifications.mine(userId, {
      ...(type ? { type } : {}),
      ...(read !== undefined ? { read: read === 'true' } : {}),
      ...(status ? { status } : {}),
    });
  }

  // Legacy-совместимость со skeleton.
  @Post(':userId')
  push(@Param('userId') userId: string, @Body() dto: { type: NotificationType }) {
    return this.notifications.send(userId, dto.type, {});
  }

  @Get(':userId')
  list(@Param('userId') userId: string) {
    return this.notifications.mine(userId);
  }

  @Post(':userId/read')
  markRead(@Param('userId') userId: string, @Body() dto: { id: string }) {
    return this.notifications.markRead(userId, dto.id);
  }

  @Post(':userId/prefs')
  setPrefs(
    @Param('userId') userId: string,
    @Body()
    dto: {
      quietHours?: { start: number; end: number };
      mutedChats?: string[];
      mutedUsers?: string[];
      favorites?: string[];
    },
  ) {
    return this.notifications.setPrefs(userId, dto);
  }

  @Get(':userId/prefs')
  getPrefs(@Param('userId') userId: string) {
    return this.notifications.getPrefsView(userId);
  }
}

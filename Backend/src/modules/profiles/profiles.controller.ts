import { Body, Controller, Delete, ForbiddenException, Get, Param, Patch, Post, Put } from '@nestjs/common';
import { ProfilesService } from './profiles.service';
import { LevelsService } from './levels.service';
import type { BlockVisibility, VerificationKind } from './profiles.service';

@Controller('profiles')
export class ProfilesController {
  constructor(
    private readonly profiles: ProfilesService,
    private readonly levels: LevelsService,
  ) {}

  @Put(':userId')
  upsert(@Param('userId') userId: string, @Body() dto: { bio: string; theme?: string }) {
    return this.profiles.upsert(userId, dto.bio, dto.theme);
  }

  @Get(':userId')
  get(@Param('userId') userId: string) {
    return this.profiles.get(userId);
  }

  // ---- Themes ----
  @Get('themes/official')
  officialThemes() {
    return this.profiles.officialThemes();
  }

  @Put(':userId/theme')
  setTheme(@Param('userId') userId: string, @Body() dto: { themeId: string; custom?: { name: string; accent: string } }) {
    return this.profiles.setTheme(userId, dto.themeId, dto.custom);
  }

  // ---- Blocks ----
  @Get(':userId/blocks')
  blocks(@Param('userId') userId: string) {
    return this.profiles.listBlocks(userId);
  }

  @Post(':userId/blocks')
  createBlock(
    @Param('userId') userId: string,
    @Body()
    dto: {
      type: string;
      position: { x: number; y: number };
      width: number;
      height: number;
      visibility: BlockVisibility;
      theme?: string;
      critical?: boolean;
      data?: Record<string, unknown>;
    },
  ) {
    return this.profiles.createBlock(userId, dto);
  }

  @Patch(':userId/blocks/:blockId')
  updateBlock(@Param('userId') userId: string, @Param('blockId') blockId: string, @Body() dto: Record<string, unknown>) {
    return this.profiles.updateBlock(userId, blockId, dto as never);
  }

  @Delete(':userId/blocks/:blockId')
  deleteBlock(@Param('userId') userId: string, @Param('blockId') blockId: string) {
    return this.profiles.deleteBlock(userId, blockId);
  }

  @Post(':userId/blocks/reorder')
  reorder(@Param('userId') userId: string, @Body() dto: { order: { id: string; position: { x: number; y: number } }[] }) {
    return this.profiles.reorderBlocks(userId, dto.order);
  }

  // ---- Badges: user endpoint всегда 403, выдача только через admin ----
  @Get(':userId/badges')
  badges(@Param('userId') userId: string) {
    return this.profiles.listBadges(userId);
  }

  @Post(':userId/badges')
  awardBadgeDenied() {
    throw new ForbiddenException('badges can only be awarded via admin API');
  }

  // ---- Verification ----
  @Post(':userId/verification')
  requestVerification(@Param('userId') userId: string, @Body() dto: { kind: VerificationKind }) {
    return this.profiles.requestVerification(userId, dto.kind);
  }

  @Get(':userId/verification')
  verification(@Param('userId') userId: string) {
    return this.profiles.verificationStatus(userId);
  }

  // ---- Feedback ----
  @Post(':targetId/feedback')
  feedback(@Param('targetId') targetId: string, @Body() dto: { fromUserId: string; kind: 'good' | 'bad' }) {
    return this.profiles.giveFeedback(dto.fromUserId, targetId, dto.kind);
  }

  @Get(':targetId/feedback')
  feedbackCounts(@Param('targetId') targetId: string) {
    return this.profiles.feedbackCounts(targetId);
  }

  // ---- XP / levels ----
  @Post(':userId/xp')
  addXp(@Param('userId') userId: string, @Body() dto: { event: string; day?: string }) {
    return this.levels.addXp(userId, dto.event, dto.day);
  }

  @Get(':userId/level')
  level(@Param('userId') userId: string) {
    return this.levels.getProgress(userId);
  }

  // ---- Streak ----
  @Post(':userId/streak')
  streak(@Param('userId') userId: string, @Body() dto: { date?: string; sessionsJoinedCount?: number }) {
    return this.profiles.recordStreakDay(userId, dto.date, dto.sessionsJoinedCount ?? 0);
  }
}

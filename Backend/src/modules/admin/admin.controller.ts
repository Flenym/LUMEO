import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, Req, UseGuards } from '@nestjs/common';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AdminService } from './admin.service';
import type { BadgeCategory } from '../profiles/profiles.service';

function actor(req: { admin?: { via: string; sub?: string } }): string {
  return req.admin?.sub ? `jwt:${req.admin.sub}` : `token:${req.admin?.via ?? 'token'}`;
}

// Отдельный auth layer: AdminGuard (X-Admin-Token или admin-JWT + deviceId).
@UseGuards(AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // ---- devices ----
  @Post('devices')
  addDevice(@Req() req: never, @Body() dto: { deviceId: string }) {
    return this.admin.addDevice(actor(req as never), dto.deviceId);
  }

  // ---- overview ----
  @Get('overview')
  overview(@Req() req: never) {
    return this.admin.overview(actor(req as never));
  }

  // ---- users ----
  @Post('users/register')
  registerUser(@Body() dto: { id: string; nickname: string }) {
    return this.admin.registerUser(dto.id, dto.nickname);
  }

  @Get('users')
  usersSearch(@Query('q') q?: string) {
    return this.admin.usersSearch(q);
  }

  @Post('users/:id/ban')
  ban(@Req() req: never, @Param('id') id: string, @Body() dto: { reason?: string }) {
    return this.admin.ban(actor(req as never), id, dto?.reason);
  }

  @Post('users/:id/unban')
  unban(@Req() req: never, @Param('id') id: string, @Body() dto: { reason?: string }) {
    return this.admin.unban(actor(req as never), id, dto?.reason);
  }

  @Post('users/:id/mute')
  mute(@Req() req: never, @Param('id') id: string, @Body() dto: { reason?: string }) {
    return this.admin.mute(actor(req as never), id, dto?.reason);
  }

  @Post('users/:id/unmute')
  unmute(@Req() req: never, @Param('id') id: string, @Body() dto: { reason?: string }) {
    return this.admin.unmute(actor(req as never), id, dto?.reason);
  }

  @Post('users/:id/verify')
  verify(@Req() req: never, @Param('id') id: string, @Body() dto: { kind: string; reason?: string }) {
    return this.admin.verify(actor(req as never), id, dto.kind, dto?.reason);
  }

  @Post('users/:id/grant')
  grant(@Req() req: never, @Param('id') id: string, @Body() dto: { ember: number; xp: number; reason?: string }) {
    return this.admin.grant(actor(req as never), id, dto.ember, dto.xp, dto?.reason);
  }

  @Post('users/:id/revoke')
  revoke(@Req() req: never, @Param('id') id: string, @Body() dto: { ember: number; xp: number; reason?: string }) {
    return this.admin.revoke(actor(req as never), id, dto.ember, dto.xp, dto?.reason);
  }

  // ---- moderation ----
  @Get('moderation/reports')
  reportClusters(@Req() req: never, @Query('clustered') clustered?: string) {
    return this.admin.reportClusters(actor(req as never), clustered !== 'false');
  }

  @Post('moderation/workshop/:itemId')
  workshopReview(
    @Req() req: never,
    @Param('itemId') itemId: string,
    @Body() dto: { approve: boolean; reason?: string },
  ) {
    return this.admin.workshopReview(actor(req as never), itemId, dto.approve, dto?.reason);
  }

  @Post('moderation/restrict/:id')
  restrict(@Req() req: never, @Param('id') id: string, @Body() dto: { scope: string; reason?: string }) {
    return this.admin.restrict(actor(req as never), id, dto.scope, dto?.reason);
  }

  @Get('moderation/log')
  moderationLog() {
    return this.admin.moderationLog();
  }

  // ---- verification ----
  @Get('verification')
  verificationList(@Req() req: never, @Query('status') status?: string) {
    return this.admin.verificationList(actor(req as never), status);
  }

  @Post('verification/:userId/:requestId')
  verificationDecide(
    @Req() req: never,
    @Param('userId') userId: string,
    @Param('requestId') requestId: string,
    @Body() dto: { approve: boolean; reason?: string },
  ) {
    return this.admin.verificationDecide(actor(req as never), userId, requestId, dto.approve, dto?.reason);
  }

  // ---- economy ----
  @Post('economy/codes')
  redeemCode(@Req() req: never, @Body() dto: { code: string; amount: number }) {
    return this.admin.redeemCode(actor(req as never), dto.code, dto.amount);
  }

  @Post('economy/items')
  itemCreate(
    @Req() req: never,
    @Body() dto: { title: string; price?: number; description?: string },
  ) {
    return this.admin.itemCreate(actor(req as never), dto.title, dto.price ?? 0, dto.description ?? '');
  }

  @Post('economy/items/:itemId/price')
  setPrice(
    @Req() req: never,
    @Param('itemId') itemId: string,
    @Body() dto: { price: number; reason?: string },
  ) {
    return this.admin.setPrice(actor(req as never), itemId, dto.price, dto?.reason);
  }

  // ---- content ----
  @Get('content/:kind')
  contentList(@Param('kind') kind: string) {
    return this.admin.contentList(kind);
  }

  @Post('content/:kind')
  contentCreate(@Req() req: never, @Param('kind') kind: string, @Body() dto: Record<string, unknown>) {
    return this.admin.contentCreate(actor(req as never), kind, dto);
  }

  @Patch('content/:kind/:id')
  contentUpdate(
    @Req() req: never,
    @Param('kind') kind: string,
    @Param('id') id: string,
    @Body() dto: Record<string, unknown>,
  ) {
    return this.admin.contentUpdate(actor(req as never), kind, id, dto);
  }

  @Delete('content/:kind/:id')
  contentDelete(@Req() req: never, @Param('kind') kind: string, @Param('id') id: string) {
    return this.admin.contentDelete(actor(req as never), kind, id);
  }

  @Post('content/badges/award')
  awardBadge(
    @Req() req: never,
    @Body() dto: { userId: string; code: string; title: string; category: BadgeCategory; reason?: string },
  ) {
    return this.admin.awardBadge(actor(req as never), dto.userId, dto, dto?.reason);
  }

  @Post('content/achievements/award')
  awardAchievement(@Req() req: never, @Body() dto: { userId: string; code: string; reason?: string }) {
    return this.admin.awardAchievement(actor(req as never), dto.userId, dto.code, dto?.reason);
  }

  // ---- analytics ----
  @Get('analytics')
  analytics(@Req() req: never) {
    return this.admin.analyticsSummary(actor(req as never));
  }

  @Post('analytics/ingest')
  ingest(@Req() req: never, @Body() dto: { type: string; userId?: string; data?: Record<string, unknown> }) {
    return this.admin.ingestEvent(actor(req as never), dto.type, dto.userId, dto.data);
  }

  // ---- server ----
  @Get('server')
  server(@Req() req: never) {
    return this.admin.serverStatus(actor(req as never));
  }

  // ---- feature flags ----
  @Get('flags')
  flags() {
    return this.admin.flagsList();
  }

  @Put('flags/:key')
  setFlagPut(@Req() req: never, @Param('key') key: string, @Body() dto: { enabled: boolean }) {
    return this.admin.setFlag(actor(req as never), key, dto.enabled);
  }

  @Post('flags')
  setFlag(@Req() req: never, @Body() dto: { key: string; enabled: boolean }) {
    return this.admin.setFlag(actor(req as never), dto.key, dto.enabled);
  }

  // ---- beta ----
  @Get('beta')
  betaList(@Req() req: never) {
    return this.admin.betaList(actor(req as never));
  }

  @Post('beta/award')
  betaAward(@Req() req: never, @Body() dto: { userId: string; reason?: string }) {
    return this.admin.betaAward(actor(req as never), dto.userId, dto?.reason);
  }

  // ---- audit ----
  @Get('audit')
  audit() {
    return this.admin.auditLog();
  }
}

import { Body, Controller, Get, Headers, Param, Post, UseGuards } from '@nestjs/common';
import { AdminGuard } from '../../common/guards/admin.guard';
import { WalletService } from './wallet.service';

@Controller('wallet')
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get(':userId')
  balance(@Param('userId') userId: string) {
    return this.wallet.balance(userId);
  }

  @Get(':userId/history')
  history(@Param('userId') userId: string) {
    return this.wallet.history(userId);
  }

  /** Grant — только admin. */
  @UseGuards(AdminGuard)
  @Post('grant')
  grant(@Body() dto: { userId: string; amount: number; reason: string; currency?: string }) {
    this.wallet.assertCurrencyName(dto.currency);
    return this.wallet.adminGrant(dto.userId, dto.amount, dto.reason);
  }

  /** Revoke — только admin. */
  @UseGuards(AdminGuard)
  @Post('revoke')
  revoke(@Body() dto: { userId: string; amount: number; reason: string; currency?: string }) {
    this.wallet.assertCurrencyName(dto.currency);
    return this.wallet.adminRevoke(dto.userId, dto.amount, dto.reason);
  }

  @Post('transfer')
  transfer(
    @Body() dto: { from: string; to: string; amount: number; currency?: string },
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    this.wallet.assertCurrencyName(dto.currency);
    return this.wallet.transfer(dto.from, dto.to, dto.amount, idempotencyKey);
  }

  @Post('gift')
  gift(@Body() dto: { from: string; to: string; amount: number; item?: string; currency?: string }) {
    this.wallet.assertCurrencyName(dto.currency);
    return this.wallet.gift(dto.from, dto.to, dto.amount, dto.item);
  }

  @Post('redeem')
  redeem(@Body() dto: { userId: string; code: string }) {
    return this.wallet.redeem(dto.userId, dto.code);
  }

  @Post('sell')
  sell(@Body() dto: { userId: string; item: string; amount: number }) {
    return this.wallet.sell(dto.userId, dto.item, dto.amount);
  }

  @Post('trade')
  trade(
    @Body()
    dto: { from: string; to: string; giveAmount: number; receiveAmount: number; giveItem?: string; receiveItem?: string },
  ) {
    return this.wallet.trade(dto.from, dto.to, dto.giveAmount, dto.receiveAmount, dto.giveItem, dto.receiveItem);
  }

  @Get('cases/table')
  rewardTable() {
    return this.wallet.rewardTable();
  }

  @Post('cases/:caseId/open')
  openCase(@Param('caseId') caseId: string, @Body() dto: { userId: string }) {
    return this.wallet.openCase(dto.userId, caseId);
  }

  @Post('premium/subscribe')
  subscribe(@Body() dto: { userId: string; plan: string }) {
    return this.wallet.subscribe(dto.userId, dto.plan);
  }

  @Get('premium/:userId')
  premiumStatus(@Param('userId') userId: string) {
    return this.wallet.premiumStatus(userId);
  }

  @Post('premium/group')
  groupSubscribe(@Body() dto: { ownerId: string; memberIds: string[]; plan: string }) {
    return this.wallet.groupSubscribe(dto.ownerId, dto.memberIds, dto.plan);
  }
}

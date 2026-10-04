import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { IsBoolean, IsOptional, IsString } from 'class-validator';
import { FriendsService, FriendSort } from './friends.service';

class SendDto {
  @IsString() from!: string;
  @IsString() to!: string;
}

class ActorDto {
  @IsOptional() @IsString() actorId?: string;
}

class FlagDto {
  @IsString() userId!: string;
  @IsString() friendId!: string;
  @IsBoolean() value!: boolean;
}

class BlockDto {
  @IsString() blocker!: string;
  @IsString() blocked!: string;
}

class RegisterUserDto {
  @IsString() userId!: string;
  @IsString() username!: string;
}

class ReorderDto {
  @IsString() userId!: string;
  @IsString({ each: true }) orderedIds!: string[];
}

@Controller('friends')
export class FriendsController {
  constructor(private readonly friends: FriendsService) {}

  @Post('register-user')
  registerUser(@Body() dto: RegisterUserDto) {
    return this.friends.registerUser(dto.userId, dto.username);
  }

  @Post('request')
  request(@Body() dto: SendDto) {
    return this.friends.send(dto.from, dto.to);
  }

  @Post(':id/accept')
  accept(@Param('id') id: string, @Body() dto: ActorDto) {
    return this.friends.accept(id, dto.actorId);
  }

  @Post(':id/decline')
  decline(@Param('id') id: string, @Body() dto: ActorDto) {
    return this.friends.decline(id, dto.actorId);
  }

  @Post('block')
  block(@Body() dto: BlockDto) {
    return this.friends.block(dto.blocker, dto.blocked);
  }

  @Post('unblock')
  unblock(@Body() dto: BlockDto) {
    return this.friends.unblock(dto.blocker, dto.blocked);
  }

  @Delete('friendship')
  removeFriend(@Body() dto: { a: string; b: string }) {
    return this.friends.removeFriend(dto.a, dto.b);
  }

  @Get('requests')
  requests(
    @Query('userId') userId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
    @Query('box') box?: 'inbox' | 'outbox' | 'all',
  ) {
    return this.friends.listRequests(userId, { cursor, limit: Number(limit || 20), box });
  }

  // Совместимость со старым GET /friends?userId=
  @Get()
  list(
    @Query('userId') userId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
    @Query('sort') sort?: FriendSort,
    @Query('q') q?: string,
  ) {
    return this.friends.listFriends(userId, { cursor, limit: Number(limit || 20), sort, q });
  }

  @Post('reorder')
  reorder(@Body() dto: ReorderDto) {
    return this.friends.reorder(dto.userId, dto.orderedIds);
  }

  @Post('favorite')
  favorite(@Body() dto: FlagDto) {
    return this.friends.setFavorite(dto.userId, dto.friendId, dto.value);
  }

  @Post('pin')
  pin(@Body() dto: FlagDto) {
    return this.friends.setPinned(dto.userId, dto.friendId, dto.value);
  }

  @Post('mute')
  mute(@Body() dto: FlagDto) {
    return this.friends.setMuted(dto.userId, dto.friendId, dto.value);
  }

  @Get('search')
  search(@Query('q') q: string, @Query('limit') limit?: string) {
    return this.friends.searchByUsername(q ?? '', Number(limit || 20));
  }

  @Get(':userId/qr')
  qr(@Param('userId') userId: string) {
    return this.friends.qrPayload(userId);
  }

  @Get('qr/resolve/:code')
  qrResolve(@Param('code') code: string) {
    return this.friends.qrResolve(code);
  }
}

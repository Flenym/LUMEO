import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { SessionState } from '../../common/engines/session.engine';
import { SessionsService } from './sessions.service';

class CreateSessionDto {
  @IsString() @MaxLength(120) title!: string;
  @IsString() @MaxLength(64) game!: string;
  @IsOptional() @IsString() @MaxLength(32) mode?: string;
  @IsOptional() @IsInt() @Min(2) @Max(10) slots?: number;
  @IsOptional() @IsString() scheduledAt?: string | null;
  @IsOptional() @IsString() @MaxLength(500) comment?: string;
  @IsString() creatorId!: string;
  @IsOptional() @IsString({ each: true }) invites?: string[];
}

class ActorDto {
  @IsString() userId!: string;
}

@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessions: SessionsService) {}

  @Post()
  create(@Body() dto: CreateSessionDto) {
    return this.sessions.create({
      title: dto.title,
      game: dto.game,
      mode: dto.mode,
      slots: dto.slots,
      scheduledAt: dto.scheduledAt ?? null,
      comment: dto.comment,
      creatorId: dto.creatorId,
      invites: dto.invites,
    });
  }

  @Get()
  list(@Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    if (cursor !== undefined || limit !== undefined) {
      return this.sessions.listPaginated({ cursor, limit: Number(limit || 20) });
    }
    return this.sessions.list();
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.sessions.get(id);
  }

  @Post(':id/transition')
  transition(@Param('id') id: string, @Body() dto: { to: SessionState; actorId?: string }) {
    return this.sessions.transition(id, dto.to, dto.actorId);
  }

  @Post(':id/invite')
  invite(@Param('id') id: string, @Body() dto: { from: string; userId: string }) {
    return this.sessions.invite(id, dto.from, dto.userId);
  }

  @Post(':id/respond')
  respond(@Param('id') id: string, @Body() dto: { userId: string; accept: boolean }) {
    return this.sessions.respond(id, dto.userId, dto.accept);
  }

  @Post(':id/join')
  join(@Param('id') id: string, @Body() dto: ActorDto) {
    return this.sessions.join(id, dto.userId);
  }

  @Post(':id/leave')
  leave(@Param('id') id: string, @Body() dto: ActorDto) {
    return this.sessions.leave(id, dto.userId);
  }

  @Post(':id/ready')
  ready(@Param('id') id: string, @Body() dto: { userId: string; status: 'ready' | 'not-ready' | 'away' }) {
    return this.sessions.setReady(id, dto.userId, dto.status);
  }

  @Post(':id/edit')
  edit(
    @Param('id') id: string,
    @Body()
    dto: { actorId: string; title?: string; comment?: string; scheduledAt?: string | null; slots?: number; mode?: string },
  ) {
    return this.sessions.edit(id, dto.actorId, dto);
  }

  @Post(':id/kick')
  kick(@Param('id') id: string, @Body() dto: { actorId: string; targetId: string }) {
    return this.sessions.kick(id, dto.actorId, dto.targetId);
  }

  @Post(':id/retime')
  retime(@Param('id') id: string, @Body() dto: { actorId: string; scheduledAt: string | null }) {
    return this.sessions.retime(id, dto.actorId, dto.scheduledAt);
  }

  @Post(':id/cancel')
  cancel(@Param('id') id: string, @Body() dto: { actorId: string }) {
    return this.sessions.cancel(id, dto.actorId);
  }

  @Post(':id/finish')
  finish(@Param('id') id: string, @Body() dto: { actorId?: string }) {
    return this.sessions.finish(id, dto.actorId);
  }

  @Post(':id/banner')
  banner(@Param('id') id: string, @Body() dto: { actorId: string; x: number; y: number; startAt: string }) {
    return this.sessions.setBanner(id, dto.actorId, { x: dto.x, y: dto.y, startAt: dto.startAt });
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Body() dto?: { actorId?: string }) {
    return this.sessions.remove(id, dto?.actorId);
  }
}

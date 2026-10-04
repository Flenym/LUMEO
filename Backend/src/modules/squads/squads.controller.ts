import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { SquadRole } from '../../common/engines/permissions.engine';
import { SquadsService } from './squads.service';

class CreateSquadDto {
  @IsString() @MaxLength(64) name!: string;
  @IsString() ownerId!: string;
  @IsOptional() @IsString() avatar?: string | null;
  @IsOptional() @IsString() chatId?: string | null;
}

@Controller('squads')
export class SquadsController {
  constructor(private readonly squads: SquadsService) {}

  @Post()
  create(@Body() dto: CreateSquadDto) {
    return this.squads.create(dto.name, dto.ownerId, { avatar: dto.avatar, chatId: dto.chatId });
  }

  @Get()
  list() {
    return this.squads.list();
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.squads.get(id);
  }

  @Post(':id/rename')
  rename(@Param('id') id: string, @Body() dto: { actorId: string; name: string }) {
    return this.squads.rename(id, dto.actorId, dto.name);
  }

  @Post(':id/avatar')
  avatar(@Param('id') id: string, @Body() dto: { actorId: string; avatar: string | null }) {
    return this.squads.setAvatar(id, dto.actorId, dto.avatar);
  }

  @Post(':id/chat')
  chat(@Param('id') id: string, @Body() dto: { actorId: string; chatId: string | null }) {
    return this.squads.setChatId(id, dto.actorId, dto.chatId);
  }

  @Post(':id/members')
  addMember(@Param('id') id: string, @Body() dto: { userId: string; role?: SquadRole }) {
    return this.squads.addMember(id, dto.userId, dto.role ?? 'Member');
  }

  @Post(':id/members/remove')
  removeMember(@Param('id') id: string, @Body() dto: { actorId: string; userId: string }) {
    return this.squads.removeMember(id, dto.actorId, dto.userId);
  }

  @Post(':id/leave')
  leave(@Param('id') id: string, @Body() dto: { userId: string }) {
    return this.squads.leave(id, dto.userId);
  }

  @Post(':id/assign')
  assign(@Param('id') id: string, @Body() dto: { actorId: string; targetId: string; role: SquadRole }) {
    return this.squads.assignRole(id, dto.actorId, dto.targetId, dto.role);
  }

  @Post(':id/invite-all')
  inviteAll(@Param('id') id: string, @Body() dto: { actorId: string; userIds: string[] }) {
    return this.squads.inviteAll(id, dto.actorId, dto.userIds);
  }

  @Get(':id/invites')
  invites(@Param('id') id: string) {
    return this.squads.listInvites(id);
  }

  @Post(':id/invites/respond')
  respondInvite(@Param('id') id: string, @Body() dto: { inviteId: string; accept: boolean }) {
    return this.squads.respondInvite(id, dto.inviteId, dto.accept);
  }

  @Post(':id/activity')
  activity(
    @Param('id') id: string,
    @Body() dto: { xpDelta?: number; playedDate?: string; won?: boolean },
  ) {
    return this.squads.recordActivity(id, dto ?? {});
  }

  @Post(':id/close')
  close(@Param('id') id: string, @Body() dto: { actorId: string }) {
    return this.squads.close(id, dto.actorId);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Body() dto?: { actorId?: string }) {
    if (!dto?.actorId) return this.squads.close(id, this.squads.get(id).ownerId);
    return this.squads.close(id, dto.actorId);
  }
}

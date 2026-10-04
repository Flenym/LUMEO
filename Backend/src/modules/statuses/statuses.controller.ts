import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { LastSeenMode, StatusTimer } from '../../common/engines/status.engine';
import { StatusesService } from './statuses.service';

class SetStatusDto {
  @IsIn(['green', 'yellow', 'red'])
  color!: 'green' | 'yellow' | 'red';

  @IsString()
  @MaxLength(140)
  text!: string;

  @IsOptional()
  @IsBoolean()
  allowEmoji?: boolean;

  @IsOptional()
  @IsIn(['15m', '30m', '1h', '2h', 'until', 'none'])
  timer?: StatusTimer;

  @IsOptional()
  @IsString()
  until?: string;

  @IsOptional()
  @IsIn(['exact', 'recent', 'hidden'])
  lastSeenMode?: LastSeenMode;

  @IsOptional()
  @IsBoolean()
  returnToPrev?: boolean;
}

@Controller('statuses')
export class StatusesController {
  constructor(private readonly statuses: StatusesService) {}

  @Put(':userId')
  set(@Param('userId') userId: string, @Body() dto: SetStatusDto) {
    return this.statuses.set(userId, dto.color, dto.text, {
      allowEmoji: dto.allowEmoji,
      timer: dto.timer,
      until: dto.until,
      lastSeenMode: dto.lastSeenMode,
      returnToPrev: dto.returnToPrev,
    });
  }

  @Get(':userId')
  get(@Param('userId') userId: string) {
    return this.statuses.get(userId);
  }

  @Delete(':userId')
  clear(@Param('userId') userId: string) {
    return this.statuses.clear(userId);
  }

  @Post(':userId/seen')
  seen(@Param('userId') userId: string, @Body() dto: { mode?: LastSeenMode }) {
    return this.statuses.touchLastSeen(userId, dto.mode);
  }

  @Post(':userId/lastseen-mode')
  lastSeenMode(@Param('userId') userId: string, @Body() dto: { mode: LastSeenMode }) {
    return this.statuses.setLastSeenMode(userId, dto.mode);
  }
}

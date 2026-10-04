import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { IsOptional, IsString } from 'class-validator';
import { UsersService } from './users.service';

class CreateUserDto {
  @IsString() username!: string;
  @IsOptional() @IsString() email?: string;
}

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Post()
  create(@Body() dto: CreateUserDto) {
    return this.users.create(dto.username, dto.email);
  }

  @Get()
  list(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    if (cursor !== undefined) return this.users.listCursor(cursor, Number(limit || 20));
    return this.users.list(Number(page || 1), Number(limit || 20));
  }

  @Get('search')
  search(@Query('q') q: string, @Query('limit') limit?: string) {
    return this.users.searchByUsername(q ?? '', Number(limit || 20));
  }

  @Get('by-username/:username')
  byUsername(@Param('username') username: string) {
    return this.users.getByUsername(username);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.users.get(id);
  }
}

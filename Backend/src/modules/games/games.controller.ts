import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { GamesService } from './games.service';

class CustomGameDto {
  @IsString()
  @MaxLength(64)
  name!: string;
}

class CustomModeDto {
  @IsString()
  @MaxLength(48)
  name!: string;
}

class FavoritesDto {
  @IsString({ each: true })
  favoriteGames!: string[];

  @IsOptional()
  @IsString()
  mainGame?: string | null;
}

@Controller('games')
export class GamesController {
  constructor(private readonly games: GamesService) {}

  @Get('catalog')
  catalog() {
    return this.games.catalogFull();
  }

  @Get('modes')
  modes() {
    return this.games.modes();
  }

  @Post('custom')
  addCustom(@Body() dto: CustomGameDto) {
    return this.games.addCustom(dto.name);
  }

  @Post('modes/custom')
  addCustomMode(@Body() dto: CustomModeDto) {
    return this.games.addCustomMode(dto.name);
  }

  @Put('user/:userId')
  setUserGames(@Param('userId') userId: string, @Body() dto: { games: string[] }) {
    return this.games.setUserGames(userId, dto.games);
  }

  @Get('user/:userId')
  getUserGames(@Param('userId') userId: string) {
    return this.games.getUserGames(userId);
  }

  @Put('user/:userId/favorites')
  setFavorites(@Param('userId') userId: string, @Body() dto: FavoritesDto) {
    return this.games.setFavorites(userId, dto.favoriteGames, dto.mainGame);
  }

  @Put('user/:userId/main')
  setMain(@Param('userId') userId: string, @Body() dto: { mainGame: string | null }) {
    return this.games.setMainGame(userId, dto.mainGame);
  }
}

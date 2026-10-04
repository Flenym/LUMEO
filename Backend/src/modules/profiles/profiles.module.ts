import { Module } from '@nestjs/common';
import { ProfilesController } from './profiles.controller';
import { ProfilesService } from './profiles.service';
import { LevelsService } from './levels.service';

@Module({
  controllers: [ProfilesController],
  providers: [ProfilesService, LevelsService],
  exports: [ProfilesService, LevelsService],
})
export class ProfilesModule {}

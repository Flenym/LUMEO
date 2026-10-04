import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { WorkshopService, WorkshopState, WorkshopFilter } from './workshop.service';

@Controller('workshop')
export class WorkshopController {
  constructor(private readonly workshop: WorkshopService) {}

  @Post()
  create(
    @Body() dto: { title: string; authorId: string; price?: number; description?: string; official?: boolean },
  ) {
    return this.workshop.create(dto.title, dto.authorId, {
      price: dto.price,
      description: dto.description,
      official: dto.official,
    });
  }

  @Get()
  list(
    @Query('filter') filter?: WorkshopFilter,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('q') q?: string,
  ) {
    return this.workshop.list(filter ?? 'All', Number(page ?? 1), Number(limit ?? 20), q);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.workshop.get(id);
  }

  @Get(':id/preview')
  preview(@Param('id') id: string) {
    return this.workshop.preview(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: { authorId: string; title?: string; description?: string; price?: number }) {
    return this.workshop.update(id, dto.authorId, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Body() dto: { authorId: string }) {
    return this.workshop.remove(id, dto.authorId);
  }

  @Post(':id/submit')
  submit(@Param('id') id: string) {
    return this.workshop.submit(id);
  }

  @Post(':id/transition')
  transition(@Param('id') id: string, @Body() dto: { to: WorkshopState; reason?: string }) {
    return this.workshop.transition(id, dto.to, dto.reason);
  }

  @Post(':id/version')
  version(
    @Param('id') id: string,
    @Body() dto: { authorId: string; title?: string; description?: string; price?: number },
  ) {
    return this.workshop.createVersion(id, dto.authorId, dto);
  }

  @Post(':id/purchase')
  purchase(@Param('id') id: string, @Body() dto: { buyerId: string }) {
    return this.workshop.purchase(id, dto.buyerId);
  }

  @Get(':id/purchases')
  purchases(@Param('id') id: string) {
    return this.workshop.purchaseHistory(id);
  }
}

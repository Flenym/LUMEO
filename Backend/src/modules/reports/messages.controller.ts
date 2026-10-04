import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { E2eeService, AttachmentMeta, DeliveryStatus } from './e2ee.service';

/**
 * Message endpoints (E2EE): хранится ТОЛЬКО MessageMetadata.
 * Любой непустой body отвергается ошибкой USE_E2EE.
 */
@Controller('messages')
export class MessagesController {
  constructor(private readonly e2ee: E2eeService) {}

  @Post()
  send(
    @Body()
    dto: {
      from: string;
      to: string;
      chatId: string;
      body?: unknown;
      attachmentMeta?: AttachmentMeta;
    },
  ) {
    return this.e2ee.send(dto);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.e2ee.get(id);
  }

  @Get('chat/:chatId')
  byChat(@Param('chatId') chatId: string) {
    return this.e2ee.byChat(chatId);
  }

  @Post(':id/delivery')
  delivery(@Param('id') id: string, @Body() dto: { status: DeliveryStatus }) {
    return this.e2ee.setDelivery(id, dto.status);
  }
}

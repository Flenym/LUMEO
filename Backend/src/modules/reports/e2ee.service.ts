import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { assertNoPlaintext } from '../../common/engines/moderation';

export type DeliveryStatus = 'sent' | 'delivered' | 'read';

export interface AttachmentMeta {
  mime: string;
  size: number;
  ref: string;
}

/**
 * MessageMetadata — ЕДИНСТВЕННОЕ, что хранит сервер о сообщениях (E2EE).
 * Никакого plaintext: поле body отсутствует в принципе, валидатор режет
 * любой непустой body ошибкой USE_E2EE. Админ видит только metadata.
 */
export interface MessageMetadata {
  id: string;
  from: string;
  to: string;
  chatId: string;
  timestamp: string;
  deliveryStatus: DeliveryStatus;
  attachmentMeta?: AttachmentMeta;
}

@Injectable()
export class E2eeService {
  private messages = new Map<string, MessageMetadata>();

  send(input: {
    from: string;
    to: string;
    chatId: string;
    body?: unknown;
    attachmentMeta?: AttachmentMeta;
  }): MessageMetadata {
    if (!input.from || !input.to || !input.chatId) {
      throw new BadRequestException('from/to/chatId required');
    }
    // Plaintext запрещён — только metadata + ciphertext-ссылки.
    assertNoPlaintext(input.body);
    const meta: MessageMetadata = {
      id: randomUUID(),
      from: input.from,
      to: input.to,
      chatId: input.chatId,
      timestamp: new Date().toISOString(),
      deliveryStatus: 'sent',
      ...(input.attachmentMeta ? { attachmentMeta: input.attachmentMeta } : {}),
    };
    this.messages.set(meta.id, meta);
    return meta;
  }

  get(id: string): MessageMetadata {
    const m = this.messages.get(id);
    if (!m) throw new BadRequestException('message not found');
    return m;
  }

  byChat(chatId: string): MessageMetadata[] {
    return [...this.messages.values()].filter((m) => m.chatId === chatId);
  }

  setDelivery(id: string, status: DeliveryStatus): MessageMetadata {
    const m = this.get(id);
    if (!['sent', 'delivered', 'read'].includes(status)) throw new BadRequestException('bad delivery status');
    m.deliveryStatus = status;
    return m;
  }

  count(): number {
    return this.messages.size;
  }
}

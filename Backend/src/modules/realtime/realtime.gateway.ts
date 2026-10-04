import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { WsRegistry } from '../../common/ws-registry';

export type PresenceStatus = 'online' | 'away' | 'offline';

interface PresenceEntry {
  socketId: string;
  status: PresenceStatus;
  lastSeenAt: string;
}

// WS endpoint: /ws (path опция socket.io). Клиент: io(API_BASE_URL, { path: '/ws', auth: { token } }).
// Auth: JWT access-токен в handshake (auth.token | query.token | Authorization: Bearer).
// Rooms: user:{id} (личные), squad:{id}, session:{id} (join/leave через событие join).
// События: chat.message/typing/presence/status.update/session.change/squad.change/receipt/reaction/message.edit/message.delete.
// Heartbeat: сервер шлёт `heartbeat` каждые 25с; клиент отвечает `pong`.
// Fallback polling — ТОЛЬКО аварийный: если сокет недоступен (режут WS),
// клиент опрашивает REST каждые 5–15 сек (GET /api/v1/sessions, /notifications и т.д.).
@Injectable()
@WebSocketGateway({ path: '/ws', cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit, OnModuleDestroy {
  @WebSocketServer()
  server!: Server;

  private presence = new Map<string, PresenceEntry>(); // userId -> entry
  private socketUser = new Map<string, string>(); // socketId -> userId
  private lastPong = new Map<string, number>(); // socketId -> ms
  private heartbeatTimer: NodeJS.Timeout | null = null;

  constructor(private readonly jwt: JwtService) {}

  onModuleInit() {
    // Heartbeat 25с: рассылка ping по всем сокетам.
    this.heartbeatTimer = setInterval(() => {
      try {
        this.server?.emit('heartbeat', { at: new Date().toISOString() });
      } catch {
        // сервер ещё не поднят — пропускаем тик
      }
    }, 25_000);
    if (this.heartbeatTimer.unref) this.heartbeatTimer.unref();
  }

  onModuleDestroy() {
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
  }

  /** Число активных WS-соединений (для /health). */
  connectionCount(): number {
    return WsRegistry.count();
  }

  getPresence(userId: string): PresenceEntry | null {
    return this.presence.get(userId) ?? null;
  }

  private tokenFromHandshake(client: Socket): string | null {
    const auth = client.handshake?.auth as Record<string, unknown> | undefined;
    if (auth && typeof auth['token'] === 'string' && auth['token']) return auth['token'] as string;
    const q = client.handshake?.query?.['token'];
    if (typeof q === 'string' && q) return q;
    const h = client.handshake?.headers?.authorization;
    if (typeof h === 'string' && h.startsWith('Bearer ')) return h.slice(7);
    return null;
  }

  async handleConnection(client: Socket) {
    const token = this.tokenFromHandshake(client);
    if (!token) {
      client.emit('error', { code: 'UNAUTHORIZED', message: 'missing JWT in handshake' });
      client.disconnect(true);
      return;
    }
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string }>(token, {
        secret: process.env.JWT_SECRET || 'dev-only-change-me',
      });
      const userId = payload.sub;
      this.socketUser.set(client.id, userId);
      WsRegistry.add(client.id);
      void client.join(`user:${userId}`);
      this.presence.set(userId, { socketId: client.id, status: 'online', lastSeenAt: new Date().toISOString() });
      client.emit('ready', { userId, heartbeatSec: 25 });
      this.server?.to(`user:${userId}`).emit('presence', { userId, status: 'online' });
    } catch {
      client.emit('error', { code: 'UNAUTHORIZED', message: 'invalid token' });
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const userId = this.socketUser.get(client.id);
    this.socketUser.delete(client.id);
    this.lastPong.delete(client.id);
    WsRegistry.remove(client.id);
    if (userId) {
      const cur = this.presence.get(userId);
      if (cur && cur.socketId === client.id) {
        this.presence.set(userId, { socketId: '', status: 'offline', lastSeenAt: new Date().toISOString() });
        this.server?.emit('presence', { userId, status: 'offline' });
      }
    }
  }

  // ---- rooms ----

  @SubscribeMessage('join')
  onJoin(@MessageBody() payload: { room: string }, @ConnectedSocket() client: Socket) {
    const room = payload?.room ?? '';
    if (!/^((user|squad|session):[\w-]+)$/.test(room)) return { ok: false, error: 'bad room' };
    void client.join(room);
    return { ok: true, room };
  }

  @SubscribeMessage('leave')
  onLeave(@MessageBody() payload: { room: string }, @ConnectedSocket() client: Socket) {
    void client.leave(payload?.room ?? '');
    return { ok: true };
  }

  @SubscribeMessage('pong')
  onPong(@ConnectedSocket() client: Socket) {
    this.lastPong.set(client.id, Date.now());
    return { ok: true };
  }

  // ---- события Tier1 (E2EE: сервер ретранслирует только ciphertext+metadata) ----

  @SubscribeMessage('chat.message')
  onChat(
    @MessageBody() payload: { to: string; ciphertext: string; messageId: string },
    @ConnectedSocket() client: Socket,
  ) {
    // TODO(db): сохранить MessageMetadata + MessageRecipient, разослать получателям.
    const from = this.socketUser.get(client.id) ?? client.id;
    const msg = { ...payload, from };
    if (payload?.to) this.server.to(`user:${payload.to}`).emit('chat.message', msg);
    else this.server.emit('chat.message', msg);
    return { ok: true };
  }

  @SubscribeMessage('typing')
  onTyping(@MessageBody() payload: { to: string; typing: boolean }, @ConnectedSocket() client: Socket) {
    const from = this.socketUser.get(client.id) ?? client.id;
    const msg = { ...payload, from };
    if (payload?.to) this.server.to(`user:${payload.to}`).emit('typing', msg);
    else this.server.emit('typing', msg);
    return { ok: true };
  }

  @SubscribeMessage('presence')
  onPresence(
    @MessageBody() payload: { userId: string; status: PresenceStatus },
    @ConnectedSocket() client: Socket,
  ) {
    const status: PresenceStatus =
      payload?.status === 'away' || payload?.status === 'offline' ? payload.status : 'online';
    if (payload?.userId) {
      this.presence.set(payload.userId, {
        socketId: client.id,
        status,
        lastSeenAt: new Date().toISOString(),
      });
      this.server.emit('presence', { ...payload, status });
    }
    return { ok: true };
  }

  @SubscribeMessage('status.update')
  onStatus(@MessageBody() payload: { userId: string; color: string; text: string }) {
    // Без пуш-спама: рассылка только по сокету, без notifications.
    this.server.emit('status.update', payload);
    return { ok: true };
  }

  @SubscribeMessage('session.change')
  onSession(@MessageBody() payload: { sessionId: string; state: string }) {
    if (payload?.sessionId) this.server.to(`session:${payload.sessionId}`).emit('session.change', payload);
    this.server.emit('session.change', payload);
    return { ok: true };
  }

  @SubscribeMessage('squad.change')
  onSquad(@MessageBody() payload: { squadId: string; change: string }) {
    if (payload?.squadId) this.server.to(`squad:${payload.squadId}`).emit('squad.change', payload);
    this.server.emit('squad.change', payload);
    return { ok: true };
  }

  @SubscribeMessage('receipt')
  onReceipt(@MessageBody() payload: { messageId: string; userId: string }) {
    this.server.emit('receipt', payload);
    return { ok: true };
  }

  @SubscribeMessage('reaction')
  onReaction(@MessageBody() payload: { messageId: string; emoji: string; userId: string }) {
    this.server.emit('reaction', payload);
    return { ok: true };
  }

  @SubscribeMessage('message.edit')
  onEdit(@MessageBody() payload: { messageId: string; ciphertext: string }) {
    this.server.emit('message.edit', payload);
    return { ok: true };
  }

  @SubscribeMessage('message.delete')
  onDelete(@MessageBody() payload: { messageId: string }) {
    this.server.emit('message.delete', payload);
    return { ok: true };
  }
}

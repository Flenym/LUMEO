// In-memory реестр WS-соединений Tier1.
// Нужен Health-контроллеру (поле wsConnections) без циклических импортов модулей.
// TODO(db): не персистится — счётчик живёт только в памяти процесса.

let connections = 0;
const sockets = new Set<string>();

export const WsRegistry = {
  add(socketId: string): number {
    if (!sockets.has(socketId)) {
      sockets.add(socketId);
      connections = sockets.size;
    }
    return connections;
  },
  remove(socketId: string): number {
    sockets.delete(socketId);
    connections = sockets.size;
    return connections;
  },
  count(): number {
    return connections;
  },
  /** Только для тестов: сбросить счётчик. */
  reset(): void {
    sockets.clear();
    connections = 0;
  },
};

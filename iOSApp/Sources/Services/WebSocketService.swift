// Lumeo — Sources/Services/WebSocketService.swift
// Realtime-канал: URLSessionWebSocketTask → /ws, heartbeat ping/pong, автопереподключение
// с exponential backoff. Rooms (join/leave), декодирование событий в типизированные
// WSEvent → @Published (lastEvent) для ChatStore/SessionStore.
// Fallback: при недоступности WS клиент переходит на polling через APIClient.

import Foundation
import Observation

// MARK: - WSConnectionState

enum WSConnectionState: Equatable {
    case disconnected, connecting, connected, fallbackPolling
}

// MARK: - WSEvent

/// Типизированное realtime-событие (decode по полю `type`).
enum WSEvent: Equatable {
    case chatMessage(chatID: UUID, messageID: UUID, senderID: UUID)
    case typing(chatID: UUID, userID: UUID, name: String, isTyping: Bool)
    case presence(userID: UUID, isOnline: Bool)
    case sessionUpdate(sessionID: UUID, state: SessionState)
    case readReceipt(chatID: UUID, messageID: UUID, readerID: UUID)
    case unknown(raw: String)
}

// MARK: - WebSocketService

/// Realtime-движок чатов/статусов/сессий. Один инстанс на приложение (передаётся через Environment).
/// Изоляция MainActor: использование только из SwiftUI (Swift 6 concurrency-safe),
/// Task-захваты self компилируются, callbacks — через MainActor.run.
@MainActor
@Observable
final class WebSocketService {
    private(set) var state: WSConnectionState = .disconnected
    /// Последнее декодированное событие — подписчики обновляют UI.
    private(set) var lastEvent: WSEvent?
    /// Активные комнаты (chatID/sessionID как строки).
    private(set) var rooms: Set<String> = []

    private var task: URLSessionWebSocketTask?
    private var heartbeat: Task<Void, Never>?
    private var receiveLoop: Task<Void, Never>?
    private var reconnectAttempts = 0

    var onMessage: ((WSEvent) -> Void)?

    // MARK: Connect

    func connect() {
        guard state == .disconnected else { return }
        state = .connecting
        let url = AppConfig.wsBaseURL.appending(path: "ws")
        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
        state = .connected
        reconnectAttempts = 0
        rejoinRooms()
        startHeartbeat()
        startReceiveLoop()
    }

    func disconnect() {
        heartbeat?.cancel()
        receiveLoop?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    // MARK: Rooms

    /// Подписка на комнату чата/сессии (presence + typing + сообщения).
    func join(room: String) {
        rooms.insert(room)
        guard state == .connected else { return }
        Task { await send(JSONPayload(type: "room.join", room: room)) }
    }

    func leave(room: String) {
        rooms.remove(room)
        guard state == .connected else { return }
        Task { await send(JSONPayload(type: "room.leave", room: room)) }
    }

    private func rejoinRooms() {
        for room in rooms {
            Task { await send(JSONPayload(type: "room.join", room: room)) }
        }
    }

    // MARK: Send

    func send(text: String) async {
        guard state == .connected else { return }
        do {
            try await task?.send(.string(text))
        } catch {
            scheduleReconnect()
        }
    }

    func send(_ payload: some Encodable) async {
        guard let data = try? JSONEncoder().encode(payload),
              let text = String(data: data, encoding: .utf8) else { return }
        await send(text: text)
    }

    /// Typing-индикатор: отправка start/stop (дебаунсится вызывающей стороной).
    func sendTyping(chatID: UUID, isTyping: Bool) async {
        await send(JSONPayload(type: isTyping ? "typing.start" : "typing.stop", room: chatID.uuidString))
    }

    /// Read receipt: сообщение прочитано.
    func sendReadReceipt(chatID: UUID, messageID: UUID) async {
        await send(JSONPayload(type: "message.read", room: chatID.uuidString, ref: messageID.uuidString))
    }

    // MARK: Heartbeat

    /// Ping каждые 25с. Потеря pong → переподключение.
    private func startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard let self, self.state == .connected else { continue }
                self.task?.sendPing { error in
                    if error != nil {
                        Task { @MainActor in self.scheduleReconnect() }
                    }
                }
            }
        }
    }

    // MARK: Receive

    private func startReceiveLoop() {
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let task = self.task, self.state == .connected else { return }
                do {
                    let message = try await task.receive()
                    if case .string(let text) = message {
                        let event = Self.decode(text)
                        await MainActor.run {
                            self.lastEvent = event
                            self.onMessage?(event)
                        }
                    }
                } catch {
                    await MainActor.run { self.scheduleReconnect() }
                    return
                }
            }
        }
    }

    // MARK: Decode

    /// Декодирование сырого JSON по полю `type` → WSEvent.
    static func decode(_ text: String) -> WSEvent {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return .unknown(raw: text)
        }
        func uuid(_ key: String) -> UUID? {
            (json[key] as? String).flatMap(UUID.init(uuidString:))
        }
        switch type {
        case "chat.message":
            guard let chat = uuid("chatId"), let msg = uuid("messageId"), let sender = uuid("senderId") else {
                return .unknown(raw: text)
            }
            return .chatMessage(chatID: chat, messageID: msg, senderID: sender)
        case "typing.start", "typing.stop":
            guard let chat = uuid("chatId"), let user = uuid("userId") else { return .unknown(raw: text) }
            return .typing(chatID: chat, userID: user, name: json["name"] as? String ?? "", isTyping: type == "typing.start")
        case "presence":
            guard let user = uuid("userId") else { return .unknown(raw: text) }
            return .presence(userID: user, isOnline: (json["online"] as? Bool) ?? false)
        case "session.update":
            guard let session = uuid("sessionId"),
                  let raw = json["state"] as? String,
                  let state = SessionState(rawValue: raw.lowercased()) ?? SessionState(rawValue: raw) else {
                return .unknown(raw: text)
            }
            return .sessionUpdate(sessionID: session, state: state)
        case "message.read":
            guard let chat = uuid("chatId"), let msg = uuid("messageId"), let reader = uuid("readerId") else {
                return .unknown(raw: text)
            }
            return .readReceipt(chatID: chat, messageID: msg, readerID: reader)
        default:
            return .unknown(raw: text)
        }
    }

    // MARK: Reconnect + polling fallback

    /// Экспоненциальный backoff (cap 30с); после 5 попыток — fallback на HTTP-polling.
    private func scheduleReconnect() {
        disconnect()
        reconnectAttempts += 1
        if reconnectAttempts > 5 {
            // FALLBACK: polling GET /api/v1/sync каждые 15с через APIClient.
            // TODO(sync): реализовать SyncPoller поверх APIClient.get("sync").
            state = .fallbackPolling
            return
        }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.state = .disconnected
            self?.connect()
        }
    }

    /// Задержка reconnect для попытки N (тестируемо).
    static func reconnectDelay(forAttempt attempt: Int) -> Double {
        min(pow(2.0, Double(max(attempt, 1))), 30)
    }
}

// MARK: - JSONPayload

/// Исходящий JSON-конверт сокета.
private struct JSONPayload: Encodable {
    var type: String
    var room: String
    var ref: String?

    init(type: String, room: String, ref: String? = nil) {
        self.type = type
        self.room = room
        self.ref = ref
    }
}

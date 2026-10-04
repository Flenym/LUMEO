// Lumeo — Sources/Services/APIClient.swift
// HTTP-клиент: API_BASE_URL из конфига, /health, /api/v1 Tier1, retry/backoff,
// offline queue с персистом в UserDefaults, X-Request-ID на каждый запрос.
// ВАЖНО: prod/CloudPub URL берётся из Info.plist (LumeoConfig.xcconfig в CI) и НЕ хардкодится.

import Foundation
import Observation

// MARK: - AppConfig

/// Конфиг окружения. Значения подставляются через Info.plist / xcconfig на CI.
/// Название валюты EMBER тоже конфигурируемо (см. ТЗ: Economy).
enum AppConfig {
    /// Базовый URL API, напр. https://api.lumeo.example. Ключ Info.plist: APIBaseURL.
    static var apiBaseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: raw) {
            return url
        }
        // Dev-фолбэк для симулятора. Прод-URL приходит только из конфига сборки.
        return URL(string: "https://api.lumeo.example")!
    }

    /// Базовый URL WebSocket (/ws). Ключ Info.plist: WSBaseURL. Если пуст — выводится из APIBaseURL.
    static var wsBaseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "WSBaseURL") as? String,
           let url = URL(string: raw) {
            return url
        }
        return apiBaseURL
    }

    /// Конфигурируемое название валюты (дефолт EMBER). Ключ Info.plist: EmberCurrencyName.
    static var currencyName: String {
        (Bundle.main.object(forInfoDictionaryKey: "EmberCurrencyName") as? String)?.uppercased() ?? "EMBER"
    }
}

// MARK: - ServerHealth

enum ServerHealth: Equatable {
    case unknown, checking, ok, unreachable
}

// MARK: - QueuedRequest

/// Офлайн-очередь: неотправленные мутации складываются сюда и реплеятся при появлении сети.
/// Персист — UserDefaults (ключ offlineQueueKey), идемпотентность по id (X-Request-ID).
struct QueuedRequest: Codable, Identifiable {
    var id: UUID
    var method: String
    var path: String
    var body: Data?
    var enqueuedAt: Date

    init(id: UUID = UUID(), method: String, path: String, body: Data? = nil, enqueuedAt: Date = .now) {
        self.id = id
        self.method = method
        self.path = path
        self.body = body
        self.enqueuedAt = enqueuedAt
    }
}

// MARK: - APIClient

/// HTTP-клиент Tier1. Один инстанс (shared), состояние очереди — @Observable для индикатора.
@Observable
final class APIClient {
    static let shared = APIClient()
    private init() {
        loadQueue()
    }

    var offlineQueue: [QueuedRequest] = [] {
        didSet { persistQueue() }
    }

    var queueCount: Int { offlineQueue.count }

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let encoder = JSONEncoder()
    private let offlineQueueKey = "lumeo.offlineQueue.v1"

    /// Максимум попыток с exponential backoff (кроме health: там 1 попытка).
    private let maxAttempts = 3

    // MARK: Health

    /// GET /health — используется стартовым overlay и Server-экраном Admin App.
    func health() async -> Bool {
        let url = AppConfig.apiBaseURL.appending(path: "health")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: Core request

    /// Задержка backoff перед попыткой N (1-based): 0.5с, 1с, 2с … cap 8с.
    static func backoffDelay(forAttempt attempt: Int) -> Double {
        min(pow(2.0, Double(max(attempt - 1, 0))) * 0.5, 8)
    }

    private func makeRequest(method: String, path: String, body: Data?, requestID: UUID) -> URLRequest {
        var request = URLRequest(url: AppConfig.apiBaseURL.appending(path: "api/v1/\(path)"))
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID.uuidString, forHTTPHeaderField: "X-Request-ID")
        // TODO(auth): Authorization: Bearer <device-token> после Auth Tier2.
        request.httpBody = body
        return request
    }

    private func sendWithRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = APIError.offline
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.badStatus }
                if (200..<300).contains(http.statusCode) {
                    return (data, http)
                }
                if http.statusCode == 429 || (500..<600).contains(http.statusCode) {
                    lastError = APIError.badStatus
                } else {
                    throw APIError.badStatus
                }
            } catch {
                lastError = error
            }
            if attempt < maxAttempts {
                let delay = Self.backoffDelay(forAttempt: attempt)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        throw lastError
    }

    // MARK: Generic /api/v1 (CRUD)

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = makeRequest(method: "GET", path: path, body: nil, requestID: UUID())
        let (data, _) = try await sendWithRetry(request)
        return try decoder.decode(T.self, from: data)
    }

    @discardableResult
    func post<T: Decodable>(_ path: String, body: Encodable?) async throws -> T {
        let payload = body.flatMap { try? encoder.encode(AnyEncodable($0)) }
        let request = makeRequest(method: "POST", path: path, body: payload, requestID: UUID())
        let (data, _) = try await sendWithRetry(request)
        return try decoder.decode(T.self, from: data)
    }

    /// Мутация без типизированного ответа: при отсутствии сети кладётся в offlineQueue вместо потери.
    /// Сигнатура сохранена для существующего кода (CreateSessionSheet).
    func post(_ path: String, body: Encodable?) async {
        let payload = body.flatMap { try? encoder.encode(AnyEncodable($0)) }
        let id = UUID()
        do {
            let request = makeRequest(method: "POST", path: path, body: payload, requestID: id)
            _ = try await sendWithRetry(request)
        } catch {
            enqueue(QueuedRequest(id: id, method: "POST", path: path, body: payload))
        }
    }

    func put(_ path: String, body: Encodable?) async {
        let payload = body.flatMap { try? encoder.encode(AnyEncodable($0)) }
        let id = UUID()
        do {
            let request = makeRequest(method: "PUT", path: path, body: payload, requestID: id)
            _ = try await sendWithRetry(request)
        } catch {
            enqueue(QueuedRequest(id: id, method: "PUT", path: path, body: payload))
        }
    }

    func patch(_ path: String, body: Encodable?) async {
        let payload = body.flatMap { try? encoder.encode(AnyEncodable($0)) }
        let id = UUID()
        do {
            let request = makeRequest(method: "PATCH", path: path, body: payload, requestID: id)
            _ = try await sendWithRetry(request)
        } catch {
            enqueue(QueuedRequest(id: id, method: "PATCH", path: path, body: payload))
        }
    }

    func delete(_ path: String) async {
        let id = UUID()
        do {
            let request = makeRequest(method: "DELETE", path: path, body: nil, requestID: id)
            _ = try await sendWithRetry(request)
        } catch {
            enqueue(QueuedRequest(id: id, method: "DELETE", path: path, body: nil))
        }
    }

    // MARK: Tier1 endpoints

    // Statuses
    func fetchStatus(userID: UUID) async throws -> UserStatus {
        try await get("statuses/\(userID.uuidString)")
    }

    func updateStatus(_ status: UserStatus) async {
        await put("statuses/me", body: status)
    }

    // Friends
    func fetchFriends() async throws -> [Friend] {
        try await get("friends")
    }

    func sendFriendRequest(username: String) async {
        await post("friends/requests", body: ["username": username])
    }

    func respondToRequest(id: UUID, accept: Bool) async {
        await post("friends/requests/\(id.uuidString)/\(accept ? "accept" : "decline")", body: nil)
    }

    func blockUser(id: UUID) async {
        await post("users/\(id.uuidString)/block", body: nil)
    }

    // Sessions
    func fetchSessions() async throws -> [GameSession] {
        try await get("sessions")
    }

    func createSession(_ session: GameSession) async {
        await post("sessions", body: session)
    }

    func transitionSession(id: UUID, to state: SessionState) async {
        await post("sessions/\(id.uuidString)/transition", body: ["to": state.backendName])
    }

    func joinSession(id: UUID) async {
        await post("sessions/\(id.uuidString)/join", body: nil)
    }

    func leaveSession(id: UUID) async {
        await post("sessions/\(id.uuidString)/leave", body: nil)
    }

    // Squads
    func fetchSquads() async throws -> [Squad] {
        try await get("squads")
    }

    func fetchSquadMembers(id: UUID) async throws -> [SquadMember] {
        try await get("squads/\(id.uuidString)/members")
    }

    func leaveSquad(id: UUID) async {
        await post("squads/\(id.uuidString)/leave", body: nil)
    }

    // Chats
    func fetchThreads() async throws -> [ChatThreadDTO] {
        try await get("chats")
    }

    func fetchMessages(chatID: UUID) async throws -> [ChatMessage] {
        try await get("chats/\(chatID.uuidString)/messages")
    }

    func sendCiphertext(_ metadata: MessageMetadata) async {
        await post("chats/\(metadata.chatID.uuidString)/messages", body: metadata)
    }

    func editMessage(chatID: UUID, messageID: UUID, ciphertext: String) async {
        await patch("chats/\(chatID.uuidString)/messages/\(messageID.uuidString)", body: ["ciphertext": ciphertext])
    }

    func deleteMessage(chatID: UUID, messageID: UUID) async {
        await delete("chats/\(chatID.uuidString)/messages/\(messageID.uuidString)")
    }

    // Notifications
    func fetchNotifications() async throws -> [NotificationItem] {
        try await get("notifications")
    }

    func markNotificationRead(id: UUID) async {
        await post("notifications/\(id.uuidString)/read", body: nil)
    }

    // Reports
    func sendReport(_ draft: ReportDraft) async {
        await post("reports", body: draft)
    }

    // Games catalog
    func fetchGames() async throws -> [Game] {
        try await get("games")
    }

    // MARK: Offline queue

    func enqueue(_ request: QueuedRequest) {
        offlineQueue.append(request)
    }

    /// Реплей офлайн-очереди после восстановления сети (по порядку, идемпотентно по id).
    func replayQueue() async {
        guard await health(), !offlineQueue.isEmpty else { return }
        let pending = offlineQueue.sorted { $0.enqueuedAt < $1.enqueuedAt }
        var failed: [QueuedRequest] = []
        for item in pending {
            do {
                let request = makeRequest(method: item.method, path: item.path, body: item.body, requestID: item.id)
                _ = try await sendWithRetry(request)
            } catch {
                failed.append(item)
            }
        }
        offlineQueue = failed
    }

    func clearQueue() {
        offlineQueue = []
    }

    // MARK: Persist

    private func persistQueue() {
        if let data = try? encoder.encode(offlineQueue) {
            UserDefaults.standard.set(data, forKey: offlineQueueKey)
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: offlineQueueKey),
              let saved = try? decoder.decode([QueuedRequest].self, from: data) else { return }
        offlineQueue = saved
    }
}

// MARK: - APIError

enum APIError: Error {
    case badStatus
    case decoding
    case offline
}

// MARK: - ChatThreadDTO / MessageMetadata (Tier1 wire shapes)

/// Превью треда для списка (wire-форма; UI-модель ChatThread — в ChatView).
struct ChatThreadDTO: Codable {
    var id: UUID
    var title: String
    var kind: ChatKind
    var lastCiphertextPreview: String?
    var unread: Int
    var isPinned: Bool
    var isMuted: Bool
}

/// E2EE metadata в сеть: только ciphertext + метаданные (зеркало Shared MessageMetadataDTO).
/// Сервер НЕ видит plaintext.
struct MessageMetadata: Codable {
    var id: UUID
    var chatID: UUID
    var senderID: UUID
    var ciphertext: String
    var keyID: String
    var nonce: String
    var kind: String
    var replyToID: UUID?
    var createdAt: Date
}

/// Type-eraser для Encodable body в очереди.
private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    init(_ value: Encodable) {
        self.encode = { try value.encode(to: $0) }
    }
    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

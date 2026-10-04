// Lumeo — Sources/Core/Models.swift
// Общие модели Main App (com.lumeo.app). Codable + Identifiable.
// Зеркалят backend-контракты (Shared/src/dto.ts, enums.ts, constants.ts).
// Backend — источник правды для форм; клиент повторяет лимиты и enum'ы.

import Foundation

// MARK: - Availability / Status

/// Статус доступности: 🟢 Свободен / 🟡 Буду позже / 🔴 Занят.
/// Зеркало Shared StatusColor.
enum Availability: String, Codable, Hashable, CaseIterable {
    case green, yellow, red
}

/// Кастомный текст статуса: лимит STATUS_MAX_LEN=140 (Shared/constants.ts),
/// без emoji по умолчанию (проверяется на клиенте, финально — сервер).
struct UserStatus: Codable, Hashable {
    /// Shared STATUS_MAX_LEN. Было 120 — приведено к паритету с backend/shared.
    static let maxTextLength = 140

    var availability: Availability
    var text: String
    var expiresAt: Date?
    var updatedAt: Date

    static func sanitized(text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxTextLength))
    }
}

/// Приватность Last Seen: точное время / «недавно» / скрыть.
/// Каноническое имя по ТЗ Tier1 — LastSeenMode; LastSeenPrivacy оставлено
/// как alias для существующего кода (SettingsView).
enum LastSeenMode: String, Codable, Hashable, CaseIterable {
    case exact, recent, hidden
}

/// Alias для обратной совместимости (SettingsView, StatusEngine).
typealias LastSeenPrivacy = LastSeenMode

/// Presence — детальное присутствие (Shared Presence: online | away | offline).
/// isOnline в User остаётся источником правды для dot; presence — расширение для WS.
enum Presence: String, Codable, Hashable, CaseIterable {
    case online, away, offline

    var isOnline: Bool { self == .online }
}

/// Длительность статуса: 15м / 30м / 1ч / 2ч / до времени / без срока.
enum StatusDuration: Codable, Hashable {
    case minutes15, minutes30, hour1, hours2
    case until(Date)
    case indefinite

    func expiry(from now: Date = .now) -> Date? {
        switch self {
        case .minutes15: now.addingTimeInterval(15 * 60)
        case .minutes30: now.addingTimeInterval(30 * 60)
        case .hour1: now.addingTimeInterval(3600)
        case .hours2: now.addingTimeInterval(7200)
        case .until(let date): date
        case .indefinite: nil
        }
    }
}

// MARK: - User / Friend

struct User: Codable, Identifiable, Hashable {
    var id: UUID
    var username: String
    var displayName: String
    var avatarURL: URL?
    var isOnline: Bool
    var lastSeenAt: Date?
    var status: UserStatus
    var currentGame: String?
    var isPlaying: Bool
    /// Расширение Tier1: детальное присутствие (маппится из isOnline по умолчанию).
    var presence: Presence = .offline

    enum CodingKeys: String, CodingKey {
        case id, username, displayName, avatarURL, isOnline, lastSeenAt, status, currentGame, isPlaying, presence
    }

    init(
        id: UUID, username: String, displayName: String, avatarURL: URL? = nil,
        isOnline: Bool, lastSeenAt: Date? = nil, status: UserStatus,
        currentGame: String? = nil, isPlaying: Bool = false, presence: Presence? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
        self.status = status
        self.currentGame = currentGame
        self.isPlaying = isPlaying
        self.presence = presence ?? (isOnline ? .online : .offline)
    }
}

struct Friend: Codable, Identifiable, Hashable {
    var id: UUID
    var user: User
    var isFavorite: Bool
    var isPinned: Bool
    var notifyWhenAvailable: Bool
    var isMuted: Bool
    /// Ручной порядок для сортировки «вручную» (FriendsView) и reorder в Home.
    var manualOrder: Int = 0
    /// Частота совместных игр (для сортировки «частота», 0...1 нормализовано).
    var playFrequency: Double = 0

    enum CodingKeys: String, CodingKey {
        case id, user, isFavorite, isPinned, notifyWhenAvailable, isMuted, manualOrder, playFrequency
    }

    init(id: UUID, user: User, isFavorite: Bool, isPinned: Bool, notifyWhenAvailable: Bool, isMuted: Bool, manualOrder: Int = 0, playFrequency: Double = 0) {
        self.id = id
        self.user = user
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.notifyWhenAvailable = notifyWhenAvailable
        self.isMuted = isMuted
        self.manualOrder = manualOrder
        self.playFrequency = playFrequency
    }
}

// MARK: - Game catalog

/// Игра из каталога (зеркало Shared STARTER_GAMES + GameDTO).
/// Кастомная игра — Game.custom(name:).
struct Game: Codable, Identifiable, Hashable {
    var id: String { slug }
    var name: String
    var slug: String
    var modes: [String]
    var platforms: [String]

    static func custom(name: String) -> Game {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return Game(name: name, slug: "custom-\(slug)", modes: ["Custom"], platforms: [])
    }
}

// MARK: - Session

/// Жизненный цикл Session: Draft → Inviting → Waiting → Ready → Live (⇄ Paused) → Finished / Cancelled.
/// Зеркало Shared SessionState (backend пишет с заглавной; Codable терпит оба регистра через init).
enum SessionState: String, Codable, Hashable, CaseIterable {
    case draft, inviting, waiting, ready, live, paused, finished, cancelled

    /// Backend пишет "Draft"/"Live" и т.д. — принимаем оба регистра.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let exact = SessionState(rawValue: raw) {
            self = exact
        } else if let lowered = SessionState(rawValue: raw.lowercased()) {
            self = lowered
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown SessionState: \(raw)")
        }
    }

    /// Каноническое имя для backend (с заглавной).
    var backendName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// Участник сессии (зеркало SessionParticipantDTO).
struct SessionParticipant: Codable, Hashable {
    var userID: UUID
    var role: SessionRole
    /// invited | accepted | declined | ready | not_ready | away | left (Shared ParticipantState).
    var state: ParticipantState
    var joinedAt: Date?
}

enum SessionRole: String, Codable, Hashable {
    case owner, participant
}

enum ParticipantState: String, Codable, Hashable {
    case invited, accepted, declined, ready, notReady = "not_ready", away, left, pending
}

struct GameSession: Codable, Identifiable, Hashable {
    var id: UUID
    var hostID: UUID
    var game: String
    var mode: String
    var minPlayers: Int
    var slotsTotal: Int
    var slotsTaken: Int
    var startsAt: Date
    var comment: String
    var invitedIDs: [UUID]
    var state: SessionState
    /// Tier1: участники с готовностью (readiness checklist в баннере/detail).
    var participants: [SessionParticipant] = []
}

/// Invite-карточка сессии у получателя: Принять / Отклонить + системное сообщение в чат.
struct InviteCard: Codable, Identifiable, Hashable {
    enum InviteState: String, Codable, Hashable {
        case pending, accepted, declined, expired
    }

    var id: UUID
    var sessionID: UUID
    var hostID: UUID
    var hostName: String
    var game: String
    var mode: String
    var startsAt: Date
    var state: InviteState
    var createdAt: Date
}

// MARK: - Squad

enum SquadRole: String, Codable, Hashable {
    case owner, admin, member
}

struct SquadMember: Codable, Identifiable, Hashable {
    var id: UUID { userID }
    var userID: UUID
    var role: SquadRole
    var joinedAt: Date
}

extension SquadMember {
    /// Display-имя через lookup превью (прод — через Users API).
    func displayName(fallback: String) -> String { fallback }
}

struct Squad: Codable, Identifiable, Hashable {
    static let maxMembers = 200

    var id: UUID
    var name: String
    var avatarURL: URL?
    var members: [SquadMember]
    var level: Int
    var xp: Int
    var streakDays: Int
}

// MARK: - Chat

enum ChatKind: String, Codable, Hashable {
    case personal, squad
}

enum AttachmentKind: String, Codable, Hashable {
    case photo, video, gif, voice
}

struct ChatAttachment: Codable, Hashable {
    var id: UUID
    var kind: AttachmentKind
    var remoteURL: URL?
    var durationSeconds: Double?
    var sizeBytes: Int?
    /// Voice: нормализованные амплитуды для waveform (0...1).
    var waveform: [Float]?
}

/// Синхронизация E2EE-сообщения: локальный plaintext виден сразу,
/// в сеть уходит только ciphertext (см. E2EEngine).
enum MessageSyncState: String, Codable, Hashable {
    /// Локальный plaintext создан, ciphertext ещё не отправлен.
    case pending
    case sent
    case delivered
    case read
    case failed
}

/// Реакции: кулак / огонь / лайк / сердце / dislike / OK. Словарь расширяем новыми ключами без миграции.
struct ChatMessage: Codable, Identifiable, Hashable {
    var id: UUID
    var chatID: UUID
    var senderID: UUID
    var text: String?
    var attachment: ChatAttachment?
    var replyToID: UUID?
    var createdAt: Date
    var editedAt: Date?
    var isDeleted: Bool
    var readByIDs: [UUID]
    var reactions: [String: [UUID]]
}

/// Полная локальная модель сообщения Tier1: plaintext хранится только на устройстве,
/// syncFlag отражает состояние E2EE-отправки. Сервер видит только ciphertext + metadata.
struct ChatMessageFull: Codable, Identifiable, Hashable {
    var id: UUID
    var chatID: UUID
    var senderID: UUID
    /// Локальный plaintext. НИКОГДА не отправляется в сеть напрямую.
    var plaintext: String?
    var attachment: ChatAttachment?
    /// Непрозрачный ciphertext для сети (base64). Сервер не расшифровывает.
    var ciphertext: String?
    var keyID: String?
    var nonce: String?
    /// 'text' | 'image' | 'video' | 'voice' | 'gif' | 'system' | 'session_invite' — только тип.
    var kind: String
    var syncFlag: MessageSyncState
    var replyToID: UUID?
    var createdAt: Date
    var editedAt: Date?
    var isDeleted: Bool
    var isPinned: Bool
    var readByIDs: [UUID]
    var reactions: [String: [UUID]]

    /// Удобный init из короткой ChatMessage (dev/превью без E2EE).
    init(from message: ChatMessage, syncFlag: MessageSyncState = .sent, kind: String = "text") {
        self.id = message.id
        self.chatID = message.chatID
        self.senderID = message.senderID
        self.plaintext = message.text
        self.attachment = message.attachment
        self.ciphertext = nil
        self.keyID = nil
        self.nonce = nil
        self.kind = kind
        self.syncFlag = syncFlag
        self.replyToID = message.replyToID
        self.createdAt = message.createdAt
        self.editedAt = message.editedAt
        self.isDeleted = message.isDeleted
        self.isPinned = false
        self.readByIDs = message.readByIDs
        self.reactions = message.reactions
    }

    init(
        id: UUID, chatID: UUID, senderID: UUID, plaintext: String? = nil,
        attachment: ChatAttachment? = nil, kind: String = "text",
        syncFlag: MessageSyncState = .pending, replyToID: UUID? = nil,
        createdAt: Date = .now, readByIDs: [UUID] = [], reactions: [String: [UUID]] = [:]
    ) {
        self.id = id
        self.chatID = chatID
        self.senderID = senderID
        self.plaintext = plaintext
        self.attachment = attachment
        self.ciphertext = nil
        self.keyID = nil
        self.nonce = nil
        self.kind = kind
        self.syncFlag = syncFlag
        self.replyToID = replyToID
        self.createdAt = createdAt
        self.editedAt = nil
        self.isDeleted = false
        self.isPinned = false
        self.readByIDs = readByIDs
        self.reactions = reactions
    }
}

enum ReactionKind: String, CaseIterable {
    case fist = "👊", fire = "🔥", like = "👍", heart = "❤️", dislike = "👎", ok = "👌"
}

// MARK: - Notifications

/// Локальная модель пуша/внутриаппового уведомления (зеркало NotificationDTO).
struct NotificationItem: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: String
    var title: String
    var body: String?
    var isRead: Bool
    var createdAt: Date
    /// Deep-link цели: lumeo://session/:id или lumeo://friend/:id.
    var linkSessionID: UUID?
    var linkFriendID: UUID?
}

// MARK: - Reports

/// Тип репорта (зеркало Shared ReportType).
enum ReportType: String, Codable, Hashable, CaseIterable {
    case spam, harassment, inappropriateContent = "inappropriate_content"
    case impersonation, cheating, other
}

/// Черновик жалобы (Tier1: собирается локально, отправляется через APIClient).
struct ReportDraft: Codable, Hashable {
    var id: UUID
    var targetUserID: UUID?
    var targetMessageID: UUID?
    var type: ReportType
    var comment: String
    var createdAt: Date

    init(targetUserID: UUID? = nil, targetMessageID: UUID? = nil, type: ReportType = .other, comment: String = "") {
        self.id = UUID()
        self.targetUserID = targetUserID
        self.targetMessageID = targetMessageID
        self.type = type
        self.comment = comment
        self.createdAt = .now
    }
}

// MARK: - Profile

/// Системные блоки неудаляемы (avatar, banner, about). Остальные — опциональны.
enum ProfileBlockKind: String, Codable, Hashable, CaseIterable {
    case avatar, banner, about, games, achievements, streak, links, photo, background

    var isSystem: Bool {
        switch self {
        case .avatar, .banner, .about: true
        default: false
        }
    }
}

struct ProfileBlock: Codable, Identifiable, Hashable {
    var id: String
    var kind: ProfileBlockKind
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var payload: [String: String]?
}

/// Layout профиля: блоки + позиции + размеры + тема + ассеты + эффекты.
/// Рендерится ТОЛЬКО через ProfileLayoutRenderer — отдельных screen'ов на тему нет.
struct ProfileLayout: Codable, Hashable {
    var blocks: [ProfileBlock]
    var themeName: String
    var backgroundAssetURL: URL?
    var effectID: String?

    static var `default`: ProfileLayout {
        ProfileLayout(
            blocks: [
                ProfileBlock(id: "avatar", kind: .avatar, x: 0, y: 0, width: 2, height: 2, payload: nil),
                ProfileBlock(id: "banner", kind: .banner, x: 0, y: 2, width: 4, height: 1, payload: nil),
                ProfileBlock(id: "about", kind: .about, x: 0, y: 3, width: 4, height: 1, payload: ["text": ""]),
                ProfileBlock(id: "games", kind: .games, x: 0, y: 4, width: 4, height: 2, payload: nil),
                ProfileBlock(id: "achievements", kind: .achievements, x: 0, y: 6, width: 2, height: 1, payload: nil),
                ProfileBlock(id: "streak", kind: .streak, x: 2, y: 6, width: 2, height: 1, payload: nil),
                ProfileBlock(id: "links", kind: .links, x: 0, y: 7, width: 4, height: 1, payload: nil),
            ],
            themeName: AppThemeName.oledOrange,
            backgroundAssetURL: nil,
            effectID: nil
        )
    }
}

// MARK: - Badges / Verification

enum Badge: String, Codable, Hashable, CaseIterable {
    case developer, official, verified, sponsor, beta, early, founder
}

enum VerificationState: String, Codable, Hashable {
    case none, pending, verified
}

// MARK: - Preview data

/// Демо-данные для #Preview и SwiftUI Previews. Не использовать в прод-коде.
enum PreviewData {
    static let me = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "you", displayName: "Вы",
        avatarURL: nil, isOnline: true, lastSeenAt: nil,
        status: UserStatus(availability: .green, text: "Го катать", expiresAt: nil, updatedAt: .now),
        currentGame: nil, isPlaying: false
    )

    static func user(id: String, username: String, displayName: String, availability: Availability, text: String, online: Bool, minutesAgo: Int, game: String? = nil, favorite: Bool = false) -> (User, Bool) {
        let user = User(
            id: UUID(uuidString: id) ?? UUID(),
            username: username, displayName: displayName,
            avatarURL: nil, isOnline: online,
            lastSeenAt: online ? nil : Date().addingTimeInterval(Double(-60 * minutesAgo)),
            status: UserStatus(availability: availability, text: text, expiresAt: nil, updatedAt: Date().addingTimeInterval(Double(-60 * max(minutesAgo / 2, 1)))),
            currentGame: game, isPlaying: game != nil,
            presence: online ? .online : .offline
        )
        return (user, favorite)
    }

    static let friends: [Friend] = {
        let seed: [(String, String, String, Availability, String, Bool, Int, String?, Bool, Bool, Double)] = [
            ("00000000-0000-0000-0000-000000000011", "neo", "Neo", .green, "Свободен, го в пати", true, 1, nil, true, true, 0.9),
            ("00000000-0000-0000-0000-000000000012", "mira", "Mira", .green, "Онлайн", true, 3, nil, false, false, 0.7),
            ("00000000-0000-0000-0000-000000000013", "dex", "Dex", .yellow, "Буду через час", false, 65, "Valorant", false, false, 0.6),
            ("00000000-0000-0000-0000-000000000014", "kate", "Kate", .red, "На созвоне", false, 12, nil, true, false, 0.5),
            ("00000000-0000-0000-0000-000000000015", "leo", "Leo", .green, "В катке", true, 2, "CS 2", false, false, 0.8),
            ("00000000-0000-0000-0000-000000000016", "ira", "Ira", .yellow, "Отошла", false, 40, nil, false, false, 0.3),
            ("00000000-0000-0000-0000-000000000017", "egor", "Егор", .green, "Готов играть", true, 1, "Fortnite", true, true, 0.95),
            ("00000000-0000-0000-0000-000000000018", "sam", "Sam", .red, "Занят до вечера", false, 180, nil, false, false, 0.1),
        ]
        return seed.enumerated().map { i, g in
            let (user, fav) = user(id: g.0, username: g.1, displayName: g.2, availability: g.3, text: g.4, online: g.5, minutesAgo: g.6, game: g.7, favorite: g.8)
            return Friend(
                id: UUID(uuidString: g.0) ?? UUID(),
                user: user,
                isFavorite: fav, isPinned: i == 0,
                notifyWhenAvailable: fav, isMuted: false,
                manualOrder: i, playFrequency: g.10
            )
        }
    }()

    static let session = GameSession(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, hostID: me.id, game: "Valorant", mode: "5x5",
        minPlayers: 2, slotsTotal: 5, slotsTaken: 3,
        startsAt: Date().addingTimeInterval(900), comment: "Чиллим, без токсиков",
        invitedIDs: [], state: .waiting,
        participants: [
            SessionParticipant(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, role: .owner, state: .ready, joinedAt: .now),
            SessionParticipant(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, role: .participant, state: .ready, joinedAt: .now),
            SessionParticipant(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000017")!, role: .participant, state: .accepted, joinedAt: .now),
        ]
    )

    static let sessions: [GameSession] = [
        session,
        GameSession(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, hostID: me.id, game: "Fortnite", mode: "Squad",
            minPlayers: 2, slotsTotal: 4, slotsTaken: 2,
            startsAt: Date().addingTimeInterval(3600), comment: "Ранкед вечером",
            invitedIDs: [], state: .inviting, participants: []
        ),
        GameSession(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, hostID: me.id, game: "Minecraft", mode: "Co-op",
            minPlayers: 2, slotsTotal: 10, slotsTaken: 10,
            startsAt: Date().addingTimeInterval(-3600), comment: "Стройка",
            invitedIDs: [], state: .live, participants: []
        ),
    ]

    static let squads: [Squad] = [
        Squad(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, name: "Night Owls", avatarURL: nil,
            members: [
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, role: .owner, joinedAt: .now),
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, role: .admin, joinedAt: .now),
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, role: .member, joinedAt: .now),
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, role: .member, joinedAt: .now),
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!, role: .member, joinedAt: .now),
            ],
            level: 7, xp: 1450, streakDays: 12
        ),
        Squad(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, name: "Casual Friday", avatarURL: nil,
            members: [
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, role: .owner, joinedAt: .now),
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, role: .member, joinedAt: .now),
                SquadMember(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!, role: .member, joinedAt: .now),
            ],
            level: 3, xp: 420, streakDays: 4
        ),
    ]

    /// Каталог игр (зеркало Shared STARTER_GAMES, 19 тайтлов).
    static let games: [Game] = [
        Game(name: "Fortnite", slug: "fortnite", modes: ["Solo", "Duo", "Squad"], platforms: ["PC", "Console", "Mobile"]),
        Game(name: "Minecraft", slug: "minecraft", modes: ["Survival", "Creative", "Co-op"], platforms: ["PC", "Console", "Mobile"]),
        Game(name: "Valorant", slug: "valorant", modes: ["5x5", "Custom"], platforms: ["PC"]),
        Game(name: "Counter-Strike 2", slug: "counter-strike-2", modes: ["5x5", "2x2"], platforms: ["PC"]),
        Game(name: "Roblox", slug: "roblox", modes: ["Custom"], platforms: ["PC", "Mobile", "Console"]),
        Game(name: "Apex Legends", slug: "apex-legends", modes: ["3x3"], platforms: ["PC", "Console"]),
        Game(name: "Call of Duty", slug: "call-of-duty", modes: ["6x6", "Warzone"], platforms: ["PC", "Console"]),
        Game(name: "GTA", slug: "gta", modes: ["Online"], platforms: ["PC", "Console"]),
        Game(name: "Rocket League", slug: "rocket-league", modes: ["2x2", "3x3"], platforms: ["PC", "Console"]),
        Game(name: "Overwatch", slug: "overwatch", modes: ["5x5"], platforms: ["PC", "Console"]),
        Game(name: "PUBG", slug: "pubg", modes: ["Squad"], platforms: ["PC", "Console", "Mobile"]),
        Game(name: "Terraria", slug: "terraria", modes: ["Co-op"], platforms: ["PC", "Console", "Mobile"]),
        Game(name: "Sea of Thieves", slug: "sea-of-thieves", modes: ["Crew"], platforms: ["PC", "Console"]),
        Game(name: "Rainbow Six Siege", slug: "rainbow-six-siege", modes: ["5x5"], platforms: ["PC", "Console"]),
        Game(name: "Destiny 2", slug: "destiny-2", modes: ["Raid", "PvP"], platforms: ["PC", "Console"]),
        Game(name: "The Finals", slug: "the-finals", modes: ["3x3"], platforms: ["PC", "Console"]),
        Game(name: "Fall Guys", slug: "fall-guys", modes: ["Party"], platforms: ["PC", "Console"]),
        Game(name: "Among Us", slug: "among-us", modes: ["Party"], platforms: ["PC", "Mobile"]),
        Game(name: "EA Sports FC", slug: "ea-sports-fc", modes: ["1x1", "2x2"], platforms: ["PC", "Console"]),
    ]

    static let inviteCard = InviteCard(
        id: UUID(), sessionID: session.id, hostID: me.id, hostName: "Neo",
        game: "Valorant", mode: "5x5", startsAt: session.startsAt,
        state: .pending, createdAt: .now
    )

    static let notifications: [NotificationItem] = [
        NotificationItem(id: UUID(), kind: "friend_available", title: "Neo свободен", body: "🟢 Neo теперь свободен", isRead: false, createdAt: .now, linkSessionID: nil, linkFriendID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")),
        NotificationItem(id: UUID(), kind: "session_invite", title: "Инвайт в Valorant", body: "Neo зовёт в 5x5", isRead: false, createdAt: .now, linkSessionID: session.id, linkFriendID: nil),
    ]
}

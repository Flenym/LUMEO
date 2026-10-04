// Lumeo — Sources/Features/Profile/ProfileModels.swift
// Tier3 identity + Tier2 retention + Tier4 economy: чистая логика (тестируемая).
// ProfileBlockDTO — единый DTO рендера (алиас Core ProfileBlock, контракт backend).

import Foundation

// MARK: - ProfileBlockDTO

/// Единый DTO профиля. Алиас Core-модели, чтобы рендер и тесты говорили на одном языке.
typealias ProfileBlockDTO = ProfileBlock

// MARK: - ProfileLayoutRules

/// Лимиты сетки 12, clamp размеров, no-overlap, guard системных блоков.
enum ProfileLayoutRules {
    static let gridColumns = 12
    static let maxBlocks = 20
    static let minSpan = 1
    static let maxSpan = 12

    static func clamped(span: Int) -> Int {
        min(max(span, minSpan), maxSpan)
    }

    static func clampedX(_ x: Int, span: Int) -> Int {
        min(max(x, 0), gridColumns - clamped(span: span))
    }

    /// Системные блоки удалять запрещено.
    static func canDelete(kind: ProfileBlockKind) -> Bool {
        !kind.isSystem
    }

    /// Проверка пересечений: (x,y,w,h) на сетке 12. Критично — no-overlap.
    static func hasOverlap(_ blocks: [ProfileBlockDTO]) -> Bool {
        var occupied: Set<String> = []
        for b in blocks {
            let w = clamped(span: b.width)
            let h = max(b.height, 1)
            for dx in 0..<w {
                for dy in 0..<h {
                    let key = "\(b.x + dx):\(b.y + dy)"
                    if occupied.contains(key) { return true }
                    occupied.insert(key)
                }
            }
        }
        return false
    }

    /// Можно ли добавить блок (лимит + место).
    static func canAdd(blocks: [ProfileBlockDTO]) -> Bool {
        blocks.count < maxBlocks
    }
}

// MARK: - WorkshopRules (5-free rule)

/// Правило публикации: минимум 5 бесплатных тем перед первой платной.
enum WorkshopRules {
    static let freeRequired = 5

    static func canPublishPaid(freeCount: Int) -> Bool {
        freeCount >= freeRequired
    }

    static func freeProgressText(freeCount: Int) -> String {
        "\(min(freeCount, freeRequired))/\(freeRequired)"
    }

    static func freeProgress(freeCount: Int) -> Double {
        min(Double(freeCount) / Double(freeRequired), 1.0)
    }
}

// MARK: - ThemeResolver

enum ThemeResolver {
    static func themeExists(named name: String) -> Bool {
        AppTheme.all.contains { $0.name == name }
    }

    static func resolve(named name: String) -> AppTheme {
        AppTheme.all.first { $0.name == name } ?? .oledOrange
    }
}

// MARK: - PlayerRank (Wood..Legend) + divisions

enum PlayerRank: String, CaseIterable {
    case wood, bronze, silver, gold, platinum, diamond, master, legend

    /// Порог входа (суммарный XP).
    var entryXP: Int {
        switch self {
        case .wood: 0
        case .bronze: 300
        case .silver: 900
        case .gold: 2000
        case .platinum: 4000
        case .diamond: 7000
        case .master: 11000
        case .legend: 16000
        }
    }

    static func rank(forXP xp: Int) -> PlayerRank {
        let table: [(PlayerRank, Int)] = [
            (.wood, 0), (.bronze, 300), (.silver, 900), (.gold, 2000),
            (.platinum, 4000), (.diamond, 7000), (.master, 11000), (.legend, 16000),
        ]
        var current: PlayerRank = .wood
        for (rank, threshold) in table where xp >= threshold { current = rank }
        return current
    }

    /// Дивизионы I–IV внутри ранга.
    static func division(forXP xp: Int) -> Int {
        let rank = rank(forXP: xp)
        let order = PlayerRank.allCases.firstIndex(of: rank) ?? 0
        let nextThreshold: Int = order + 1 < PlayerRank.allCases.count
            ? rankThreshold(PlayerRank.allCases[order + 1]) : rankThreshold(.legend) + 5000
        let base = rankThreshold(rank)
        let span = max(nextThreshold - base, 1)
        let progress = Double(xp - base) / Double(span)
        return min(4, max(1, 4 - Int(progress * 4)))
    }

    private static func rankThreshold(_ rank: PlayerRank) -> Int {
        switch rank {
        case .wood: 0
        case .bronze: 300
        case .silver: 900
        case .gold: 2000
        case .platinum: 4000
        case .diamond: 7000
        case .master: 11000
        case .legend: 16000
        }
    }

    var localizationKey: String { "level.rank.\(rawValue)" }
}

// MARK: - Birthday

enum BirthdayHelper {
    static func isToday(birthday: Date?, today: Date = .now) -> Bool {
        guard let birthday else { return false }
        let cal = Calendar.current
        return cal.component(.day, from: birthday) == cal.component(.day, from: today)
            && cal.component(.month, from: birthday) == cal.component(.month, from: today)
    }
}

// MARK: - FeedbackStore (1 vote / 24h guard)

/// Метр 👍/👎 с guard: один голос в 24 часа (на устройство, сервер перепроверяет).
struct FeedbackStore {
    var lastVoteAt: Date?
    var likes: Int
    var dislikes: Int

    func canVote(now: Date = .now) -> Bool {
        guard let last = lastVoteAt else { return true }
        return now.timeIntervalSince(last) >= 24 * 3600
    }

    mutating func vote(like: Bool, now: Date = .now) -> Bool {
        guard canVote(now: now) else { return false }
        if like { likes += 1 } else { dislikes += 1 }
        lastVoteAt = now
        return true
    }
}

// MARK: - Wallet (Tier4)

enum LedgerStatus: String, Codable, Hashable {
    case pending, completed, failed, refunded
}

struct EmberLedgerEntry: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var transactionID: String
    var from: String
    var to: String
    var item: String?
    var amount: Int
    var at: Date = .now
    var status: LedgerStatus
}

/// Idempotency: повторный send с тем же ключом не дублирует запись.
struct WalletLedger {
    private(set) var entries: [EmberLedgerEntry] = []
    private var idempotencyKeys: Set<String> = []

    mutating func append(_ entry: EmberLedgerEntry, idempotencyKey: String) -> Bool {
        guard !idempotencyKeys.contains(idempotencyKey) else { return false }
        idempotencyKeys.insert(idempotencyKey)
        entries.insert(entry, at: 0)
        return true
    }
}

// MARK: - Store / Cases / Gifts (Tier4, без азарта)

struct StoreItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var priceEmber: Int
    var isFree: Bool
    var isAdminIssued: Bool
    var canGift: Bool
}

struct CaseReward: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var chancePercent: Double
}

struct GiftItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var from: String
    var canAccept: Bool
    var canSell: Bool
    var canUse: Bool
    var canRegift: Bool
}

// MARK: - Extended profile content (payload-контракт рендера)

/// Payload-ключи ProfileBlockDTO для Steam-like страницы.
enum ProfilePayloadKey {
    static let text = "text"
    static let mainGame = "mainGame"
    static let favorites = "favorites" // CSV
    static let photos = "photos" // CSV urls
    static let sessions = "sessions" // CSV "game · result"
    static let opacity = "opacity"
    static let accent = "accent"
}

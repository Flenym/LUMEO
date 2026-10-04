// Lumeo — Sources/Core/Engines/XPEngine.swift
// XP, уровни, ранги и дивизионы. Паритет с backend XpService
// (Backend/src/common/engines/xp.engine.ts):
// XP-таблица xpForEvent, формула уровня floor(sqrt(xp/100))+1,
// ранги Wood..Legend по порогам уровня. Дивизионы (I/II/III) — клиентское
// отображение внутри ранга (backend хранит только level/rank).
// Анти-спам: message_sent даёт 0 XP.

import Foundation

// MARK: - XPRank

/// Ранг по уровню — зеркало backend Rank 1-в-1.
enum XPRank: String, CaseIterable {
    case wood = "Wood"
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
    case legend = "Legend"
}

/// Дивизион внутри ранга (клиентское отображение): III → II → I к вершине ранга.
enum XPDivision: String, CaseIterable {
    case three = "III", two = "II", one = "I"
}

// MARK: - XPEngine

enum XPEngine {
    // MARK: XP table (паритет backend XP_TABLE)

    /// XP за событие — зеркало backend xpForEvent 1-в-1.
    /// Неизвестные события → 0. message_sent → 0 (анти-спам).
    static func xpForEvent(_ event: String) -> Int {
        switch event {
        case "session_complete": 50
        case "session_join": 10
        case "streak_day": 5
        case "achievement": 30
        case "message_sent": 0
        default: 0
        }
    }

    // MARK: Level (паритет backend levelForXp)

    /// Уровень по суммарному XP — зеркало backend levelForXp:
    /// floor(sqrt(xp/100)) + 1. xp<0 трактуется как 0.
    static func levelForXp(_ xp: Int) -> Int {
        let safe = max(0, xp)
        return Int(floor(sqrt(Double(safe) / 100.0))) + 1
    }

    // MARK: Rank (паритет backend rankForLevel)

    /// Ранг по уровню — зеркало backend rankForLevel 1-в-1.
    static func rankForLevel(_ level: Int) -> XPRank {
        if level >= 30 { return .legend }
        if level >= 25 { return .diamond }
        if level >= 20 { return .platinum }
        if level >= 15 { return .gold }
        if level >= 10 { return .silver }
        if level >= 5 { return .bronze }
        return .wood
    }

    // MARK: Divisions (клиентское отображение)

    /// Нижняя граница уровня для ранга (для расчёта дивизиона).
    static func levelFloor(for rank: XPRank) -> Int {
        switch rank {
        case .wood: 1
        case .bronze: 5
        case .silver: 10
        case .gold: 15
        case .platinum: 20
        case .diamond: 25
        case .legend: 30
        }
    }

    /// Верхняя граница уровня ранга (включительно). Legend открыт сверху.
    static func levelCeil(for rank: XPRank) -> Int? {
        switch rank {
        case .wood: 4
        case .bronze: 9
        case .silver: 14
        case .gold: 19
        case .platinum: 24
        case .diamond: 29
        case .legend: nil
        }
    }

    /// Дивизион внутри ранга: нижняя треть → III, средняя → II, верхняя → I.
    /// Legend без дивизионов (всегда I).
    static func division(forLevel level: Int) -> XPDivision {
        let rank = rankForLevel(level)
        guard rank != .legend, let ceil = levelCeil(for: rank) else { return .one }
        let floor = levelFloor(for: rank)
        let span = max(ceil - floor + 1, 1)
        let offset = level - floor
        if offset < span / 3 { return .three }
        if offset < (2 * span) / 3 { return .two }
        return .one
    }

    /// Полное отображение «Gold II» (Legend — без дивизиона).
    static func rankDisplay(forLevel level: Int) -> String {
        let rank = rankForLevel(level)
        guard rank != .legend else { return XPRank.legend.rawValue }
        return "\(rank.rawValue) \(division(forLevel: level).rawValue)"
    }

    // MARK: Progress

    /// XP-порог входа на уровень (обратная формула: (level-1)² * 100).
    static func xpThreshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (level - 1) * (level - 1) * 100
    }

    /// Прогресс внутри текущего уровня, 0...1.
    static func progress(xp: Int) -> Double {
        let level = levelForXp(xp)
        let floor = xpThreshold(forLevel: level)
        let ceil = xpThreshold(forLevel: level + 1)
        guard ceil > floor else { return 1 }
        return min(1, max(0, Double(xp - floor) / Double(ceil - floor)))
    }

    // MARK: Session reward (клиентский convenience поверх таблицы)

    /// XP за завершённую совместную сессию: база session_complete (50)
    /// + бонус за размер пати и длительность (клиентский прогноз; финально — сервер).
    static func xpForFinishedSession(playerCount: Int, durationMinutes: Int) -> Int {
        let base = xpForEvent("session_complete")
        let partyBonus = max(0, playerCount - 1) * 10
        let durationBonus = min(max(durationMinutes, 0), 180) / 6
        return base + partyBonus + durationBonus
    }

    // MARK: Legacy (deprecated)

    /// Легаси-кривая, заменена формулой backend. Оставлена для совместимости.
    @available(*, deprecated, message: "Use levelForXp(_:) — backend parity formula.")
    static func xpForLevel(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return 100 * level * (level + 1) / 2
    }

    /// Легаси-уровень, заменён levelForXp. Оставлен для совместимости.
    @available(*, deprecated, message: "Use levelForXp(_:) — backend parity formula.")
    static func level(forXP xp: Int) -> Int {
        var level = 0
        while xpForLevel(level + 1) <= xp {
            level += 1
        }
        return level
    }
}

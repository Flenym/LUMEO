// Lumeo — Sources/Core/Engines/StatusEngine.swift
// Чистая логика статусов. Паритет с backend StatusService
// (Backend/src/common/engines/status.engine.ts):
// normalize/validColor, TTL 24ч (STATUS_TTL_MS), inactive 5 мин (INACTIVE_AFTER_MS),
// resolveAfterExpiry → сброс в 🟢, Last Seen по настройке приватности.
// Без зависимостей от UI — покрыта Tests/EnginesTests.swift.

import Foundation

// MARK: - StatusStrings

/// Локализуемые строки движка (инжектятся, дефолт RU). Вью не хардкодят тексты.
struct StatusStrings {
    var online: String
    var offline: String
    var recently: String
    var hidden: String
    var lastSeenPrefix: String

    static let russian = StatusStrings(
        online: "В сети", offline: "Не в сети", recently: "недавно",
        hidden: "скрыто", lastSeenPrefix: "был(а)"
    )
    static let english = StatusStrings(
        online: "Online", offline: "Offline", recently: "recently",
        hidden: "hidden", lastSeenPrefix: "last seen"
    )
}

// MARK: - StatusEngine

enum StatusEngine {
    // MARK: Backend parity constants

    /// TTL статуса до авто-истечения — зеркало backend STATUS_TTL_MS (24ч).
    static let statusTTL: TimeInterval = 24 * 60 * 60

    /// Порог inactive — зеркало backend INACTIVE_AFTER_MS (5 мин):
    /// lastSeen старше 5 мин → серый dot, карточка уходит вниз.
    static let inactiveThreshold: TimeInterval = 5 * 60

    static let validColors: [Availability] = [.green, .yellow, .red]

    // MARK: Normalize / validation (паритет normalizeStatus / isValidColor)

    /// Принимает только green|yellow|red — зеркало backend isValidColor.
    static func isValidColor(_ raw: String) -> Bool {
        Availability(rawValue: raw) != nil
    }

    /// Нормализация статуса — зеркало backend normalizeStatus:
    /// trim, fallback 🟢 при невалидном цвете, обрезка до STATUS_MAX_LEN=140.
    static func normalized(availability: Availability?, text: String?, now: Date = .now) -> UserStatus {
        let safeAvailability = availability ?? .green
        let safeText = UserStatus.sanitized(text: text ?? "")
        return UserStatus(availability: safeAvailability, text: safeText, expiresAt: nil, updatedAt: now)
    }

    // MARK: Expiry (паритет shouldAutoExpire / resolveAfterExpiry)

    /// Статус протух? — зеркало backend shouldAutoExpire (updatedAt + TTL <= now).
    static func shouldAutoExpire(updatedAt: Date, now: Date = .now, ttl: TimeInterval = statusTTL) -> Bool {
        now.timeIntervalSince(updatedAt) >= ttl
    }

    /// Сброс после истечения TTL — зеркало backend resolveAfterExpiry:
    /// возврат к дефолту (🟢 + пустой текст).
    static func resolveAfterExpiry(now: Date = .now) -> UserStatus {
        UserStatus(availability: .green, text: "", expiresAt: nil, updatedAt: now)
    }

    // MARK: Effective status (клиентский слой поверх backend)

    /// Эффективный статус с учётом явного таймера expiresAt: срок вышел → авто-возврат в 🟢.
    static func effectiveAvailability(status: UserStatus, now: Date = .now) -> Availability {
        if let expiry = status.expiresAt, expiry <= now {
            return .green
        }
        if shouldAutoExpire(updatedAt: status.updatedAt, now: now) {
            return .green
        }
        return status.availability
    }

    /// Остаток явного таймера статуса, если задан.
    static func remaining(status: UserStatus, now: Date = .now) -> TimeInterval? {
        guard let expiry = status.expiresAt else { return nil }
        let left = expiry.timeIntervalSince(now)
        return left > 0 ? left : nil
    }

    // MARK: Inactive (паритет backend isInactive)

    /// Пользователь считается inactive при отсутствии дольше 5 мин.
    /// Онлайн — никогда не inactive. Без lastSeen — inactive (зеркало backend: NaN → true).
    static func isInactive(lastSeenAt: Date?, isOnline: Bool, now: Date = .now) -> Bool {
        if isOnline { return false }
        guard let last = lastSeenAt else { return true }
        return now.timeIntervalSince(last) > inactiveThreshold
    }

    /// Миллисекундная перегрузка 1-в-1 с backend isInactive(lastSeenAtMs, nowMs).
    static func isInactive(lastSeenAtMs: Double, nowMs: Double) -> Bool {
        guard lastSeenAtMs.isFinite, nowMs.isFinite else { return true }
        return nowMs - lastSeenAtMs > inactiveThreshold * 1000
    }

    // MARK: Last Seen

    /// Текст Last Seen: точное время / «недавно» / скрыто.
    static func lastSeenText(
        lastSeenAt: Date?,
        isOnline: Bool,
        privacy: LastSeenPrivacy,
        now: Date = .now,
        strings: StatusStrings = .russian
    ) -> String {
        if isOnline { return strings.online }
        guard let last = lastSeenAt else { return strings.offline }
        switch privacy {
        case .hidden:
            return strings.hidden
        case .recent:
            return strings.recently
        case .exact:
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "\(strings.lastSeenPrefix) \(formatter.localizedString(for: last, relativeTo: now))"
        }
    }
}

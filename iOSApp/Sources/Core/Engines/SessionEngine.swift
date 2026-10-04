// Lumeo — Sources/Core/Engines/SessionEngine.swift
// Чистая логика игровых Session. Паритет с backend SessionService
// (Backend/src/common/engines/session.engine.ts):
// граф переходов canTransition, readyCount (ready+accepted),
// isReadyToStart по minRequired. Клиент не может перескочить состояния.

import Foundation

// MARK: - SessionEngine

enum SessionEngine {
    // MARK: Slots

    /// Свободных слотов осталось.
    static func slotsLeft(_ session: GameSession) -> Int {
        max(0, session.slotsTotal - session.slotsTaken)
    }

    /// Можно ли войти: активное состояние + есть слоты.
    static func canJoin(_ session: GameSession) -> Bool {
        switch session.state {
        case .inviting, .waiting, .ready, .live:
            return slotsLeft(session) > 0
        case .draft, .paused, .finished, .cancelled:
            return false
        }
    }

    /// Готовность к старту по счётчику слотов: минимум игроков набран.
    static func canStart(_ session: GameSession) -> Bool {
        switch session.state {
        case .waiting, .ready:
            return session.slotsTaken >= session.minPlayers
        default:
            return false
        }
    }

    // MARK: Transitions (паритет backend TRANSITIONS / canTransition)

    /// Разрешённые переходы — клиент не может перескочить состояния.
    /// Зеркало backend TRANSITIONS 1-в-1.
    static func allowedTransitions(from state: SessionState) -> [SessionState] {
        switch state {
        case .draft: return [.inviting, .cancelled]
        case .inviting: return [.waiting, .cancelled]
        case .waiting: return [.ready, .cancelled]
        case .ready: return [.live, .cancelled]
        case .live: return [.paused, .finished, .cancelled]
        case .paused: return [.live, .finished, .cancelled]
        case .finished, .cancelled: return []
        }
    }

    /// Разрешён ли переход from → to — зеркало backend canTransition.
    static func canTransition(from: SessionState, to: SessionState) -> Bool {
        allowedTransitions(from: from).contains(to)
    }

    // MARK: Readiness (паритет readyCount / isReadyToStart)

    /// Готовых участников: state ready или accepted — зеркало backend readyCount.
    static func readyCount(_ participants: [SessionParticipant]) -> Int {
        participants.filter { $0.state == .ready || $0.state == .accepted }.count
    }

    /// Можно стартовать: готовых >= minRequired (дефолт 2) — зеркало backend isReadyToStart.
    static func isReadyToStart(_ participants: [SessionParticipant], minRequired: Int = 2) -> Bool {
        readyCount(participants) >= minRequired
    }

    // MARK: Display

    /// Текст счётчика «x/y игроков».
    static func occupancyText(_ session: GameSession) -> String {
        "\(session.slotsTaken)/\(session.slotsTotal)"
    }

    /// Короткий статус готовности «Егор ✓, Neo …» для баннера (readiness checklist).
    static func readinessSummary(_ participants: [SessionParticipant], names: [UUID: String]) -> String {
        participants.map { p in
            let name = names[p.userID] ?? String(localized: "session.player")
            let mark = (p.state == .ready || p.state == .accepted) ? "✓" : "…"
            return "\(name) \(mark)"
        }.joined(separator: ", ")
    }
}

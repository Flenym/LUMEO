// Lumeo — Tests/EnginesTests.swift
// XCTest для чистой логики: Status / Session / Streak / XP.
// Паритет с backend (Backend/test/*.spec.ts + Shared/contracts).
import XCTest

@testable import LumeoApp

// MARK: - StatusEngineTests

final class StatusEngineTests: XCTestCase {
    private func status(availability: Availability, expiresAt: Date? = nil, updatedAt: Date = .now) -> UserStatus {
        UserStatus(availability: availability, text: "test", expiresAt: expiresAt, updatedAt: updatedAt)
    }

    /// Таймер вышел → авто-возврат в 🟢.
    func testAutoReturnToGreenAfterExpiry() {
        let expired = status(availability: .red, expiresAt: Date().addingTimeInterval(-60))
        XCTAssertEqual(StatusEngine.effectiveAvailability(status: expired), .green)
    }

    /// Активный таймер сохраняет статус.
    func testKeepsAvailabilityBeforeExpiry() {
        let active = status(availability: .yellow, expiresAt: Date().addingTimeInterval(600))
        XCTAssertEqual(StatusEngine.effectiveAvailability(status: active), .yellow)
    }

    /// Без срока — статус как есть, remaining nil.
    func testIndefiniteHasNoRemaining() {
        let indefinite = status(availability: .green)
        XCTAssertNil(StatusEngine.remaining(status: indefinite))
    }

    /// Паритет backend normalizeStatus: trim + fallback green + обрезка 140.
    func testNormalizeTrimsAndDefaults() {
        let normalized = StatusEngine.normalized(availability: nil, text: "  hi  ")
        XCTAssertEqual(normalized.availability, .green)
        XCTAssertEqual(normalized.text, "hi")
        let long = StatusEngine.normalized(availability: .red, text: String(repeating: "x", count: 200))
        XCTAssertEqual(long.text.count, UserStatus.maxTextLength)
        XCTAssertEqual(UserStatus.maxTextLength, 140)
    }

    /// Паритет backend isValidColor: только green|yellow|red.
    func testValidColors() {
        XCTAssertTrue(StatusEngine.isValidColor("green"))
        XCTAssertTrue(StatusEngine.isValidColor("yellow"))
        XCTAssertTrue(StatusEngine.isValidColor("red"))
        XCTAssertFalse(StatusEngine.isValidColor("blue"))
    }

    /// Паритет backend shouldAutoExpire: TTL 24ч.
    func testAutoExpireAfter24h() {
        let now = Date()
        XCTAssertTrue(StatusEngine.shouldAutoExpire(updatedAt: now.addingTimeInterval(-25 * 3600), now: now))
        XCTAssertFalse(StatusEngine.shouldAutoExpire(updatedAt: now.addingTimeInterval(-3600), now: now))
    }

    /// Паритет backend resolveAfterExpiry: сброс в дефолт.
    func testResolveAfterExpiryResets() {
        let next = StatusEngine.resolveAfterExpiry()
        XCTAssertEqual(next.availability, .green)
        XCTAssertEqual(next.text, "")
    }

    /// Паритет backend isInactive: порог 5 мин (было 30 дней — приведено к backend).
    func testInactiveAfter5Minutes() {
        let now = Date()
        XCTAssertEqual(StatusEngine.inactiveThreshold, 5 * 60)
        XCTAssertTrue(StatusEngine.isInactive(lastSeenAt: now.addingTimeInterval(-6 * 60), isOnline: false, now: now))
        XCTAssertFalse(StatusEngine.isInactive(lastSeenAt: now.addingTimeInterval(-60), isOnline: false, now: now))
        XCTAssertFalse(StatusEngine.isInactive(lastSeenAt: nil, isOnline: true, now: now))
        XCTAssertTrue(StatusEngine.isInactive(lastSeenAt: nil, isOnline: false, now: now))
    }

    /// Миллисекундная перегрузка 1-в-1 с backend; NaN → true.
    func testInactiveMsOverload() {
        XCTAssertTrue(StatusEngine.isInactive(lastSeenAtMs: 0, nowMs: 6 * 60_000))
        XCTAssertFalse(StatusEngine.isInactive(lastSeenAtMs: 0, nowMs: 60_000))
        XCTAssertTrue(StatusEngine.isInactive(lastSeenAtMs: .nan, nowMs: 0))
    }

    /// Last Seen: hidden / recent / exact / online.
    func testLastSeenPrivacyModes() {
        let last = Date().addingTimeInterval(-3600)
        XCTAssertEqual(
            StatusEngine.lastSeenText(lastSeenAt: last, isOnline: false, privacy: .hidden),
            StatusStrings.russian.hidden
        )
        XCTAssertEqual(
            StatusEngine.lastSeenText(lastSeenAt: last, isOnline: false, privacy: .recent),
            StatusStrings.russian.recently
        )
        XCTAssertEqual(
            StatusEngine.lastSeenText(lastSeenAt: nil, isOnline: true, privacy: .exact),
            StatusStrings.russian.online
        )
        XCTAssertEqual(
            StatusEngine.lastSeenText(lastSeenAt: nil, isOnline: false, privacy: .exact),
            StatusStrings.russian.offline
        )
    }
}

// MARK: - SessionEngineTests

final class SessionEngineTests: XCTestCase {
    private func session(state: SessionState, taken: Int, total: Int = 5) -> GameSession {
        GameSession(
            id: UUID(), hostID: UUID(), game: "Valorant", mode: "5x5",
            minPlayers: 2, slotsTotal: total, slotsTaken: taken,
            startsAt: .now, comment: "", invitedIDs: [], state: state
        )
    }

    private func participant(_ state: ParticipantState) -> SessionParticipant {
        SessionParticipant(userID: UUID(), role: .participant, state: state, joinedAt: nil)
    }

    func testSlotsLeftNeverNegative() {
        XCTAssertEqual(SessionEngine.slotsLeft(session(state: .waiting, taken: 7)), 0)
        XCTAssertEqual(SessionEngine.slotsLeft(session(state: .waiting, taken: 3)), 2)
    }

    /// Войти можно только в активное состояние с местами; finished/cancelled — нет.
    func testCanJoinOnlyActiveWithSlots() {
        XCTAssertTrue(SessionEngine.canJoin(session(state: .waiting, taken: 3)))
        XCTAssertFalse(SessionEngine.canJoin(session(state: .waiting, taken: 5)))
        XCTAssertFalse(SessionEngine.canJoin(session(state: .finished, taken: 1)))
        XCTAssertFalse(SessionEngine.canJoin(session(state: .draft, taken: 0)))
    }

    /// Старт — при набранном минимуме.
    func testCanStartRequiresMinPlayers() {
        XCTAssertFalse(SessionEngine.canStart(session(state: .waiting, taken: 1)))
        XCTAssertTrue(SessionEngine.canStart(session(state: .waiting, taken: 2)))
        XCTAssertFalse(SessionEngine.canStart(session(state: .live, taken: 5)))
    }

    /// Переходы идут по графу, из finished/cancelled выхода нет.
    func testAllowedTransitions() {
        XCTAssertEqual(SessionEngine.allowedTransitions(from: .draft), [.inviting, .cancelled])
        XCTAssertTrue(SessionEngine.allowedTransitions(from: .live).contains(.paused))
        XCTAssertTrue(SessionEngine.allowedTransitions(from: .paused).contains(.live))
        XCTAssertTrue(SessionEngine.allowedTransitions(from: .finished).isEmpty)
    }

    /// Паритет backend canTransition: валидные переходы.
    func testValidTransitions() {
        XCTAssertTrue(SessionEngine.canTransition(from: .draft, to: .inviting))
        XCTAssertTrue(SessionEngine.canTransition(from: .ready, to: .live))
        XCTAssertTrue(SessionEngine.canTransition(from: .live, to: .paused))
    }

    /// Паритет backend: невалидные переходы.
    func testInvalidTransitions() {
        XCTAssertFalse(SessionEngine.canTransition(from: .draft, to: .live))
        XCTAssertFalse(SessionEngine.canTransition(from: .finished, to: .live))
        XCTAssertFalse(SessionEngine.canTransition(from: .live, to: .draft))
    }

    /// Паритет backend: cancel из live-состояний.
    func testCancelFromLiveStates() {
        XCTAssertTrue(SessionEngine.canTransition(from: .paused, to: .cancelled))
        XCTAssertTrue(SessionEngine.canTransition(from: .waiting, to: .cancelled))
    }

    /// Паритет backend readyCount: ready+accepted.
    func testReadyCount() {
        let list = [participant(.ready), participant(.accepted), participant(.pending)]
        XCTAssertEqual(SessionEngine.readyCount(list), 2)
    }

    /// Паритет backend isReadyToStart по minRequired.
    func testReadyToStartRespectsMin() {
        XCTAssertFalse(SessionEngine.isReadyToStart([participant(.ready)], minRequired: 2))
        XCTAssertTrue(SessionEngine.isReadyToStart([participant(.ready)], minRequired: 1))
    }
}

// MARK: - StreakEngineTests

final class StreakEngineTests: XCTestCase {
    private var calendar: Calendar { StreakEngine.utcCalendar }

    private func daysAgo(_ n: Int, from base: Date) -> Date {
        calendar.date(byAdding: .day, value: -n, to: base)!
    }

    /// Три дня подряд → streak 3.
    func testThreeDayStreak() {
        let today = Date()
        let dates = [daysAgo(0, from: today), daysAgo(1, from: today), daysAgo(2, from: today)]
        XCTAssertEqual(StreakEngine.currentStreak(sessionDates: dates, today: today), 3)
    }

    /// Разрыв позавчера → streak 1 (сегодня есть).
    func testGapResetsStreak() {
        let today = Date()
        let dates = [daysAgo(0, from: today), daysAgo(2, from: today)]
        XCTAssertEqual(StreakEngine.currentStreak(sessionDates: dates, today: today), 1)
    }

    /// Последняя сессия раньше вчера → 0.
    func testOldSessionsGiveZero() {
        let today = Date()
        XCTAssertEqual(StreakEngine.currentStreak(sessionDates: [daysAgo(5, from: today)], today: today), 0)
        XCTAssertEqual(StreakEngine.currentStreak(sessionDates: [], today: today), 0)
    }

    /// Две сессии в один день считаются за один день.
    func testSameDayCountsOnce() {
        let today = Date()
        let dates = [today, today.addingTimeInterval(-3600), daysAgo(1, from: today)]
        XCTAssertEqual(StreakEngine.currentStreak(sessionDates: dates, today: today), 2)
    }

    /// Паритет backend: первый день начинает streak.
    func testFirstDayStartsStreak() throws {
        let result = try StreakEngine.updateStreak(lastDateStr: nil, todayStr: "2026-10-03")
        XCTAssertEqual(result, StreakResult(streak: 1, broken: false))
    }

    /// Паритет backend: подряд идущий день инкрементит.
    func testConsecutiveDayIncrements() throws {
        let result = try StreakEngine.updateStreak(lastDateStr: "2026-10-02", todayStr: "2026-10-03", currentStreak: 3)
        XCTAssertEqual(result, StreakResult(streak: 4, broken: false))
    }

    /// Паритет backend: тот же день сохраняет streak.
    func testSameDayKeepsStreak() throws {
        let result = try StreakEngine.updateStreak(lastDateStr: "2026-10-03", todayStr: "2026-10-03", currentStreak: 5)
        XCTAssertEqual(result, StreakResult(streak: 5, broken: false))
    }

    /// Паритет backend: разрыв обнуляет с broken=true.
    func testGapBreaksStreak() throws {
        let result = try StreakEngine.updateStreak(lastDateStr: "2026-10-01", todayStr: "2026-10-03", currentStreak: 5)
        XCTAssertEqual(result, StreakResult(streak: 1, broken: true))
    }

    /// Паритет backend: невалидная дата бросает ошибку.
    func testInvalidDateThrows() {
        XCTAssertThrowsError(try StreakEngine.updateStreak(lastDateStr: "nope", todayStr: "2026-10-03"))
        XCTAssertThrowsError(try StreakEngine.updateStreak(lastDateStr: nil, todayStr: "2026-13-99"))
    }

    /// Паритет backend squadDayActivity: нужен joined-сессии день.
    func testSquadDayActivity() {
        XCTAssertTrue(StreakEngine.squadDayActivity(sessionsJoined: true))
        XCTAssertFalse(StreakEngine.squadDayActivity(sessionsJoined: false))
    }
}

// MARK: - XPEngineTests

final class XPEngineTests: XCTestCase {
    /// Паритет backend: значения XP-таблицы.
    func testXpTableValues() {
        XCTAssertEqual(XPEngine.xpForEvent("session_complete"), 50)
        XCTAssertEqual(XPEngine.xpForEvent("session_join"), 10)
        XCTAssertEqual(XPEngine.xpForEvent("streak_day"), 5)
        XCTAssertEqual(XPEngine.xpForEvent("achievement"), 30)
    }

    /// Паритет backend: анти-спам message_sent → 0, неизвестные → 0.
    func testSpamProtection() {
        XCTAssertEqual(XPEngine.xpForEvent("message_sent"), 0)
        XCTAssertEqual(XPEngine.xpForEvent("unknown_event"), 0)
    }

    /// Паритет backend: формула уровня floor(sqrt(xp/100))+1.
    func testLevelFormula() {
        XCTAssertEqual(XPEngine.levelForXp(0), 1)
        XCTAssertEqual(XPEngine.levelForXp(100), 2)
        XCTAssertEqual(XPEngine.levelForXp(400), 3)
        XCTAssertEqual(XPEngine.levelForXp(-50), 1)
    }

    /// Паритет backend: пороги рангов.
    func testRankThresholds() {
        XCTAssertEqual(XPEngine.rankForLevel(1), .wood)
        XCTAssertEqual(XPEngine.rankForLevel(5), .bronze)
        XCTAssertEqual(XPEngine.rankForLevel(10), .silver)
        XCTAssertEqual(XPEngine.rankForLevel(15), .gold)
        XCTAssertEqual(XPEngine.rankForLevel(20), .platinum)
        XCTAssertEqual(XPEngine.rankForLevel(25), .diamond)
        XCTAssertEqual(XPEngine.rankForLevel(30), .legend)
    }

    /// Высокие уровни — Legend.
    func testHighLevelsAreLegend() {
        XCTAssertEqual(XPEngine.rankForLevel(99), .legend)
    }

    /// Дивизионы: нижняя треть → III, верхняя → I; Legend всегда I.
    func testDivisions() {
        XCTAssertEqual(XPEngine.division(forLevel: 5), .three)
        XCTAssertEqual(XPEngine.division(forLevel: 9), .one)
        XCTAssertEqual(XPEngine.division(forLevel: 30), .one)
        XCTAssertEqual(XPEngine.division(forLevel: 99), .one)
    }

    /// Отображение «Gold II», Legend без дивизиона.
    func testRankDisplay() {
        XCTAssertEqual(XPEngine.rankDisplay(forLevel: 30), "Legend")
        XCTAssertTrue(XPEngine.rankDisplay(forLevel: 16).hasPrefix("Gold"))
    }

    func testProgressIsUnitRange() {
        let progress = XPEngine.progress(xp: 150)
        XCTAssertTrue(progress > 0 && progress < 1)
        XCTAssertEqual(XPEngine.progress(xp: 0), 0, accuracy: 0.001)
    }

    func testXpRewardScalesWithParty() {
        let solo = XPEngine.xpForFinishedSession(playerCount: 1, durationMinutes: 30)
        let party = XPEngine.xpForFinishedSession(playerCount: 5, durationMinutes: 30)
        XCTAssertGreaterThan(party, solo)
        XCTAssertEqual(solo, 50 + 0 + 5)
    }
}

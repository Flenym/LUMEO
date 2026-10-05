// Lumeo — Sources/Core/Engines/StreakEngine.swift
// Streak засчитывается ТОЛЬКО за реальные совместные Session (finished).
// Паритет с backend StreakService (Backend/src/common/engines/streak.engine.ts):
// updateStreak(lastDateStr:todayStr:currentStreak:) на UTC-днях YYYY-MM-DD,
// squadDayActivity. Timezone-устойчиво: дни нормализуются в UTC,
// а не в локальной зоне устройства. Покрыт Tests/EnginesTests.swift.

import Foundation

// MARK: - StreakResult

/// Результат пересчёта — зеркало backend StreakResult.
struct StreakResult: Equatable {
    var streak: Int
    var broken: Bool
}

// MARK: - StreakEngine

enum StreakEngine {
    /// UTC без force unwrap: secondsFromGMT:0 всегда валиден, но fallback
    /// оставлен для Swift 6 safety (продовый краш-риск из аудита).
    private static let utcTimeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current

    /// Фиксированный UTC-календарь: streak не ломается при смене часового пояса.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        return calendar
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: Backend parity — updateStreak

    /// Пересчёт streak — зеркало backend updateStreak 1-в-1:
    /// - lastDateStr nil → первый день, streak=1
    /// - diff 0 (дважды в один день) → streak без изменений, broken=false
    /// - diff 1 → streak+1
    /// - diff >1 → broken=true, streak=1
    /// Даты — YYYY-MM-DD в UTC. Невалидный формат бросает ошибку (как backend).
    static func updateStreak(
        lastDateStr: String?,
        todayStr: String,
        currentStreak: Int = 0
    ) throws -> StreakResult {
        guard let today = parseDay(todayStr) else {
            throw StreakError.invalidDate(todayStr)
        }
        guard let lastStr = lastDateStr else {
            return StreakResult(streak: 1, broken: false)
        }
        guard let last = parseDay(lastStr) else {
            throw StreakError.invalidDate(lastStr)
        }
        let diffDays = Int(round(Double(today - last) / 86_400))
        if diffDays <= 0 { return StreakResult(streak: currentStreak, broken: false) }
        if diffDays == 1 { return StreakResult(streak: currentStreak + 1, broken: false) }
        return StreakResult(streak: 1, broken: true)
    }

    /// Активность дня сквада — зеркало backend squadDayActivity:
    /// день засчитывается только при joined-сессии.
    static func squadDayActivity(sessionsJoined: Bool) -> Bool {
        sessionsJoined == true
    }

    // MARK: Client helpers (поверх backend-логики)

    /// YYYY-MM-DD строка UTC-дня для даты.
    static func dayString(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Уникальные календарные дни (UTC) из дат завершённых сессий, по убыванию.
    static func distinctDays(from dates: [Date], calendar: Calendar = utcCalendar) -> [Date] {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        return days.sorted(by: >)
    }

    /// Текущий streak: сколько подряд дней (включая сегодня/вчера) были сессии.
    /// - Если последняя сессия раньше вчера — streak = 0.
    static func currentStreak(
        sessionDates: [Date],
        today: Date = Date(),
        calendar: Calendar = utcCalendar
    ) -> Int {
        let days = distinctDays(from: sessionDates, calendar: calendar)
        guard let latest = days.first else { return 0 }

        let todayStart = calendar.startOfDay(for: today)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return 0 }
        guard latest == todayStart || latest == yesterdayStart else { return 0 }

        var streak = 1
        var cursor = latest
        for day in days.dropFirst() {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            if day == prev {
                streak += 1
                cursor = day
            } else {
                break
            }
        }
        return streak
    }

    // MARK: Private

    /// Парсинг YYYY-MM-DD в полночь UTC (секунды). Зеркало backend parseDay.
    private static func parseDay(_ string: String) -> Int? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = utcCalendar.date(from: components) else { return nil }
        // Строгая проверка формата (как regex backend): "2026-10-3" невалидно.
        guard dayFormatter.string(from: date) == string else { return nil }
        return Int(date.timeIntervalSince1970)
    }
}

// MARK: - StreakError

enum StreakError: Error, Equatable {
    case invalidDate(String)
}

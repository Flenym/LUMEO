// Lumeo — Sources/Features/Profile/StreakView.swift
// Tier2: personal + squad 🔥, календарь 7 дней.

import SwiftUI

// MARK: - StreakView

struct StreakView: View {
    @Environment(ThemeManager.self) private var theme
    var personalDays: Int
    var squadDays: Int
    var compact: Bool = false
    /// Активные дни текущей недели (0 = Пн). Демо: последние `personalDays` подряд.
    var activeWeekdays: [Bool] = [true, true, true, true, true, false, false]

    /// Короткие символы дней недели с понедельника (без хардкода строк).
    private var weekdaySymbols: [String] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Пн
        let symbols = cal.shortWeekdaySymbols // Вс..Сб
        return (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                streakCell(
                    value: personalDays,
                    label: String(localized: "profile.streak.personal"),
                    systemImage: "flame.fill"
                )
                Divider().frame(height: 40)
                streakCell(
                    value: squadDays,
                    label: String(localized: "profile.streak.squad"),
                    systemImage: "person.3.fill"
                )
            }
            if !compact {
                Text(String(localized: "profile.streak.calendar"))
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.textSecondary)
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(activeWeekdays[i] ? theme.current.primary : theme.current.surfaceSecondary)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if activeWeekdays[i] {
                                        Image(systemName: "flame.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                }
                            Text(weekdaySymbols[i])
                                .font(.caption2)
                                .foregroundStyle(theme.current.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(weekdaySymbols[i]) \(activeWeekdays[i] ? "🔥" : "—")")
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    private func streakCell(value: Int, label: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.current.primary)
                .font(.title2)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("🔥 \(value)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.current.text)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack {
        StreakView(personalDays: 12, squadDays: 8)
        StreakView(personalDays: 3, squadDays: 1, compact: true)
    }
    .padding()
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
    .background(.black)
}

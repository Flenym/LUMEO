// Lumeo — Sources/Features/Profile/AchievementsView.swift
// Tier2: AchievementsGrid + BadgesRow.
// Бейджи: Verified (синяя галка), Sponsor (градиент), Developer (premium),
// корона owner/founder, Beta (градиент), Early, Official.

import SwiftUI

// MARK: - LumeoAchievement

struct LumeoAchievement: Identifiable, Hashable {
    var id: String
    var progress: Double // 0...1
    var isUnlocked: Bool { progress >= 1 }
}

// MARK: - AchievementsGrid

struct AchievementsGrid: View {
    @Environment(ThemeManager.self) private var theme
    var compact: Bool = false

    private let items: [LumeoAchievement] = [
        .init(id: "first-session", progress: 1),
        .init(id: "party-5", progress: 1),
        .init(id: "streak-7", progress: 0.7),
        .init(id: "squad-10", progress: 0.4),
        .init(id: "host-20", progress: 1),
        .init(id: "early-bird", progress: 0.2),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "profile.achievements"), systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(theme.current.text)
                Spacer()
                Text("24 / 150")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.current.textSecondary)
            }
            BadgesRow(badges: [.verified, .sponsor, .developer, .official, .beta, .early, .founder])
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(compact ? Array(items.prefix(3)) : items) { item in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(item.isUnlocked ? theme.current.primary.opacity(0.25) : theme.current.surfaceSecondary)
                                .frame(width: 56, height: 56)
                            Image(systemName: item.isUnlocked ? "trophy.fill" : "lock.fill")
                                .foregroundStyle(item.isUnlocked ? theme.current.warning : theme.current.textSecondary)
                        }
                        ProgressView(value: item.progress)
                            .tint(theme.current.primary)
                            .frame(width: 56)
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel(item.id)
                    .accessibilityValue("\(Int(item.progress * 100))%")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }
}

// MARK: - BadgesRow

struct BadgesRow: View {
    var badges: [Badge]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(badges, id: \.self) { BadgeView(badge: $0) }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel(
            badges.map { String(localized: "profile.badge.\($0.rawValue)") }.joined(separator: ", ")
        )
    }
}

#Preview {
    AchievementsGrid()
        .padding()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
        .background(.black)
}

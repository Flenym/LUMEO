// Lumeo — Sources/Features/Profile/LevelView.swift
// НОВЫЙ Tier2: Level ring + XP bar + rank Wood..Legend + дивизионы +
// rewards grid (avatar-frames / borders / chat-frames / effects).

import SwiftUI

// MARK: - LevelView

struct LevelView: View {
    @Environment(ThemeManager.self) private var theme
    var xp: Int
    var compact: Bool = false

    private var level: Int { XPEngine.level(forXP: xp) }
    private var progress: Double { XPEngine.progress(xp: xp) }
    private var rank: PlayerRank { PlayerRank.rank(forXP: xp) }
    private var division: Int { PlayerRank.division(forXP: xp) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Level ring.
                ZStack {
                    Circle()
                        .stroke(theme.current.surfaceSecondary, lineWidth: 10)
                        .frame(width: 76, height: 76)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [theme.current.primary, theme.current.secondary]),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                    Text("\(level)")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(theme.current.text)
                }
                .accessibilityLabel("\(String(localized: "level.title")) \(level)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "level.title"))
                        .font(.headline)
                        .foregroundStyle(theme.current.text)
                    Text("\(String(localized: "\(rank.localizationKey)")) · \(String(localized: "level.division")) \(division)")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.current.secondary)
                    // XP bar.
                    ProgressView(value: progress)
                        .tint(theme.current.primary)
                        .accessibilityLabel("\(String(localized: "level.xp")) \(xp)")
                    Text("\(xp) \(String(localized: "level.xp"))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.current.textSecondary)
                }
            }
            if !compact {
                rewardsGrid
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    private var rewardsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "level.rewards"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                rewardCell(icon: "person.crop.circle.badge.checkmark", key: "level.reward.frames", locked: level < 2)
                rewardCell(icon: "square.dashed", key: "level.reward.borders", locked: level < 4)
                rewardCell(icon: "bubble.left.fill", key: "level.reward.chatframes", locked: level < 6)
                rewardCell(icon: "sparkles", key: "level.reward.effects", locked: level < 8)
            }
        }
    }

    private func rewardCell(icon: String, key: String, locked: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: locked ? "lock.fill" : icon)
                .foregroundStyle(locked ? theme.current.textSecondary : theme.current.primary)
            Text(String(localized: "\(key)"))
                .font(.caption)
                .foregroundStyle(theme.current.text)
            Spacer()
        }
        .padding(10)
        .frame(minHeight: 44)
        .background(theme.current.surfaceSecondary, in: .rect(cornerRadius: 10))
        .accessibilityLabel(String(localized: "\(key)"))
    }
}

#Preview {
    VStack {
        LevelView(xp: 2450)
        LevelView(xp: 120, compact: true)
    }
    .padding()
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
    .background(.black)
}

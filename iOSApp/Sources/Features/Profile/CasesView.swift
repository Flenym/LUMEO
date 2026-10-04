// Lumeo — Sources/Features/Profile/CasesView.swift
// Tier4: прозрачная reward table, без азарта (шансы видны ДО открытия).

import SwiftUI

// MARK: - CasesView

struct CasesView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var opened: String?

    private let rewards: [CaseReward] = [
        CaseReward(title: "Common frame", chancePercent: 60),
        CaseReward(title: "Rare border", chancePercent: 25),
        CaseReward(title: "Epic effect", chancePercent: 10),
        CaseReward(title: "Legendary glow", chancePercent: 5),
    ]

    var body: some View {
        List {
            Section(String(localized: "cases.rewards")) {
                ForEach(rewards) { reward in
                    HStack {
                        Text(reward.title)
                            .foregroundStyle(theme.current.text)
                        Spacer()
                        Text("\(Int(reward.chancePercent))%")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(theme.current.secondary)
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
                Text(String(localized: "workshop.free"))
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
            }
            Section {
                Button(String(localized: "cases.open")) {
                    opened = rewards.first?.title
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.current.primary)
                .frame(minHeight: 44)
                if let opened {
                    Label(opened, systemImage: "gift.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(String(localized: "cases.title"))
    }
}

#Preview {
    NavigationStack { CasesView() }
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

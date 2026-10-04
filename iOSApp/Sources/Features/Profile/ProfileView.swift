// Lumeo — Sources/Features/Profile/ProfileView.swift
// Длинная Steam-like страница. Рендер — ТОЛЬКО ProfileLayoutRenderer.
// Верификация бейджа — только через Admin App (Verification).

import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var layout: ProfileLayout = .default
    @State private var isEditing = false
    @State private var showWallet = false

    /// Демо-день рождения: сегодня (чтобы показать 🎂-кейс).
    private var demoBirthday: Date { .now }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ProfileLayoutRenderer(
                        layout: layout,
                        user: PreviewData.me,
                        badges: [.verified, .sponsor, .founder],
                        streakDays: 12,
                        squadStreakDays: 8,
                        xp: 2450,
                        birthday: demoBirthday,
                        squads: PreviewData.squads
                    )
                    LevelView(xp: 2450, compact: true)
                    StreakView(personalDays: 12, squadDays: 8, compact: true)
                    AchievementsGrid(compact: true)
                }
                .padding()
            }
            .background(theme.current.background)
            .navigationTitle(String(localized: "tab.profile"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showWallet = true
                    } label: {
                        Image(systemName: "wallet.pass.fill")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "wallet.title"))
                    Button(isEditing ? String(localized: "common.done") : String(localized: "profile.edit")) {
                        isEditing.toggle()
                    }
                    .frame(minHeight: 44)
                }
            }
            .sheet(isPresented: $isEditing) {
                ProfileEditorView(layout: $layout)
            }
            .navigationDestination(isPresented: $showWallet) { WalletView() }
        }
        .tint(theme.current.primary)
    }
}

#Preview {
    ProfileView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

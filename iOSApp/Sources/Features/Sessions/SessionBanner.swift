// Lumeo — Sources/Features/Sessions/SessionBanner.swift
// Баннер активной Session в чате: счётчик x/y игроков, кнопки Войти/Выйти,
// таймер до старта, readiness checklist («Егор ✓, Neo …»).
// Live-статус дублируется в Live Activity + Dynamic Island (LiveSessionActivity).

import SwiftUI

// MARK: - SessionBanner

struct SessionBanner: View {
    @Environment(ThemeManager.self) private var theme
    var session: GameSession
    var isJoined: Bool
    /// Имена участников для checklist (userID → displayName). Пусто — checklist скрыт.
    var names: [UUID: String] = [:]
    var onJoin: () -> Void
    var onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title3)
                    .foregroundStyle(theme.current.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.game)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.current.text)
                        Text("· \(SessionEngine.occupancyText(session))")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.textSecondary)
                    }
                    // Таймер обратного отсчёта до старта.
                    if session.startsAt > .now {
                        Text(timerInterval: Date()...session.startsAt, countsDown: true)
                            .font(.caption)
                            .foregroundStyle(theme.current.secondary)
                    } else {
                        Text(String(localized: "session.live"))
                            .font(.caption.bold())
                            .foregroundStyle(theme.current.danger)
                    }
                }
                Spacer()
                if isJoined {
                    Button {
                        Haptics.leave()
                        onLeave()
                    } label: {
                        Text(String(localized: "session.leave"))
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.current.danger)
                    .controlSize(.small)
                } else if SessionEngine.canJoin(session) {
                    Button {
                        Haptics.join()
                        onJoin()
                    } label: {
                        Text(String(localized: "session.join"))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.current.primary)
                    .controlSize(.small)
                }
            }
            // Readiness checklist: «Егор ✓, Neo …» (если есть участники и имена).
            if !session.participants.isEmpty, !names.isEmpty {
                Text(SessionEngine.readinessSummary(session.participants, names: names))
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .sensoryFeedback(.impact, trigger: isJoined)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.game), \(SessionEngine.occupancyText(session))")
    }
}

#Preview {
    VStack(spacing: 12) {
        SessionBanner(session: PreviewData.session, isJoined: false, onJoin: {}, onLeave: {})
        SessionBanner(
            session: PreviewData.session, isJoined: true,
            names: [
                PreviewData.me.id: "Вы",
                UUID(uuidString: "00000000-0000-0000-0000-000000000011")!: "Neo",
                UUID(uuidString: "00000000-0000-0000-0000-000000000017")!: "Егор",
            ],
            onJoin: {}, onLeave: {}
        )
    }
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
    .padding()
    .background(.black)
}

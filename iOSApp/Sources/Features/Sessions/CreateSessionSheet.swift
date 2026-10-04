// Lumeo — Sources/Features/Sessions/CreateSessionSheet.swift
// Создание Session: игра из каталога + custom / режим / слоты 2–10 / время
// (date picker + быстрые чипы «Сегодня 18:00») / коммент max140 / multi-invite.
// Черновик (Draft) → отправка инвайтов (Inviting). Invite-карточка «Принять/Отклонить»
// у получателя в чате + системное сообщение.

import SwiftUI

// MARK: - CreateSessionSheet

struct CreateSessionSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var prefilledFriend: Friend? = nil

    @State private var selectedGame: Game?
    @State private var customGame = ""
    @State private var useCustom = false
    @State private var mode = "5x5"
    @State private var slots = 5
    @State private var startsAt = Self.todayAt18
    @State private var comment = ""
    @State private var invited: Set<UUID> = []
    @State private var inviteQuery = ""
    @State private var createdSession: GameSession?
    @State private var error: String?
    /// UITesting-фаза потока (LumeoUITests, flow 4): waiting → accepted → live → finished.
    @State private var uitestPhase: UITestSessionPhase?

    private let modes = ["1x1", "2x2", "3x3", "5x5", "Squad", "Custom"]

    /// Быстрый чип «Сегодня 18:00» (если 18:00 прошло — завтра, иначе confirm disabled).
    static var todayAt18: Date {
        let calendar = Calendar.current
        var candidate = calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: .now))
            ?? .now.addingTimeInterval(3600)
        if candidate <= .now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate)
                ?? candidate.addingTimeInterval(86400)
        }
        return candidate
    }

    static var tomorrowAt20: Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return calendar.date(byAdding: .hour, value: 20, to: tomorrow) ?? .now.addingTimeInterval(7200)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "session.game")) {
                    Toggle(String(localized: "session.game.custom"), isOn: $useCustom)
                    if useCustom {
                        TextField(String(localized: "session.game.hint"), text: $customGame)
                    } else {
                        Picker(String(localized: "session.game"), selection: $selectedGame) {
                            Text(String(localized: "session.game.pick")).tag(nil as Game?)
                            ForEach(PreviewData.games) { game in
                                Text(game.name).tag(game as Game?)
                            }
                        }
                        .accessibilityIdentifier("session.create.game")
                    }
                    Picker(String(localized: "session.mode"), selection: $mode) {
                        ForEach(modes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("\(String(localized: "session.slots")): \(slots)", value: $slots, in: 2...10)
                        .accessibilityValue("\(slots)")
                }
                Section(String(localized: "session.time")) {
                    HStack(spacing: 8) {
                        Button(String(localized: "session.time.today")) { startsAt = Self.todayAt18 }
                            .buttonStyle(.bordered)
                            .tint(theme.current.secondary)
                            .controlSize(.small)
                        Button(String(localized: "session.time.tomorrow")) { startsAt = Self.tomorrowAt20 }
                            .buttonStyle(.bordered)
                            .tint(theme.current.secondary)
                            .controlSize(.small)
                    }
                    DatePicker(String(localized: "session.startsAt"), selection: $startsAt, in: Date()...)
                }
                Section(String(localized: "session.comment")) {
                    TextField(String(localized: "session.comment.hint"), text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                    HStack {
                        Spacer()
                        Text("\(comment.count)/140")
                            .font(.caption2)
                            .foregroundStyle(comment.count > 140 ? theme.current.danger : theme.current.textSecondary)
                    }
                }
                Section(String(localized: "session.invite")) {
                    TextField(String(localized: "friends.search"), text: $inviteQuery)
                        .textInputAutocapitalization(.never)
                    ForEach(inviteCandidates) { friend in
                        Toggle(isOn: Binding(
                            get: { invited.contains(friend.id) || friend.id == prefilledFriend?.id },
                            set: { isOn in
                                if isOn { invited.insert(friend.id) } else { invited.remove(friend.id) }
                            }
                        )) {
                            Text(friend.user.displayName)
                        }
                        .tint(theme.current.primary)
                    }
                }
                if let error {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(theme.current.danger)
                    }
                }
                if let createdSession {
                    Section(String(localized: "session.created")) {
                        Text("\(createdSession.game) · \(SessionEngine.occupancyText(createdSession))")
                    }
                }
                // UITesting-поток flow 4 (без сети, локальный state machine).
                if UITesting.isActive, uitestPhase != nil {
                    uitestFlowSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "session.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "session.sendInvites")) {
                        createDraft()
                    }
                    .disabled(!canCreate)
                    .accessibilityIdentifier("session.create.confirm")
                }
            }
        }
        .tint(theme.current.primary)
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .onAppear {
            selectedGame = PreviewData.games.first(where: { $0.slug == "valorant" })
            if let prefilledFriend {
                invited.insert(prefilledFriend.id)
            }
        }
    }

    // MARK: - Validation / Draft → Inviting

    private var gameName: String {
        useCustom ? customGame.trimmingCharacters(in: .whitespacesAndNewlines) : (selectedGame?.name ?? "")
    }

    private var canCreate: Bool {
        !gameName.isEmpty && comment.count <= 140 && startsAt > .now
    }

    private var inviteCandidates: [Friend] {
        guard !inviteQuery.isEmpty else { return PreviewData.friends }
        return PreviewData.friends.filter {
            $0.user.username.localizedCaseInsensitiveContains(inviteQuery)
                || $0.user.displayName.localizedCaseInsensitiveContains(inviteQuery)
        }
    }

    private func createDraft() {
        let cleanComment = String(comment.prefix(140))
        var session = GameSession(
            id: UUID(), hostID: PreviewData.me.id, game: gameName, mode: mode,
            minPlayers: 2, slotsTotal: slots, slotsTaken: 1,
            startsAt: startsAt, comment: cleanComment,
            invitedIDs: Array(invited), state: .draft
        )
        // Переход Draft → Inviting (проверка через SessionEngine).
        guard SessionEngine.canTransition(from: .draft, to: .inviting) else {
            error = String(localized: "session.error.transition")
            Haptics.error()
            return
        }
        session.state = .inviting
        Haptics.sessionCreated()
        Task { await APIClient.shared.post("sessions", body: session) }
        createdSession = session
        if UITesting.isActive {
            // В тестах шит не закрываем: дальше идёт flow-панель.
            uitestPhase = .waiting
        } else {
            dismiss()
        }
    }

    // MARK: - UITesting flow (waiting → accepted → live → finished)

    private enum UITestSessionPhase {
        case waiting, accepted, live, finished
    }

    @ViewBuilder
    private var uitestFlowSection: some View {
        Section("Flow") {
            switch uitestPhase {
            case .waiting:
                Text("Waiting for players")
                    .accessibilityIdentifier("session.banner.waiting")
                Button("Invite") {
                    Haptics.selection()
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        uitestPhase = .accepted
                    }
                }
                .accessibilityIdentifier("session.invite")
            case .accepted:
                Text("Invite accepted ✓")
                    .accessibilityIdentifier("session.invite.accepted")
                Button("Join") {
                    Haptics.join()
                    uitestPhase = .live
                }
                .accessibilityIdentifier("session.join")
            case .live:
                Text("Live")
                    .accessibilityIdentifier("session.banner.live")
                Button(String(localized: "session.finish")) {
                    Haptics.success()
                    uitestPhase = .finished
                }
                .accessibilityIdentifier("session.finish")
            case .finished:
                Text("Finished")
                    .accessibilityIdentifier("session.banner.finished")
            case nil:
                EmptyView()
            }
        }
    }
}

// MARK: - SessionInviteCard

/// Invite-карточка у получателя в чате: игра, хост, время, кнопки Принять / Отклонить
/// + системное сообщение в тред после решения.
struct SessionInviteCard: View {
    @Environment(ThemeManager.self) private var theme
    var session: GameSession
    var hostName: String
    var onAccept: () -> Void
    var onDecline: () -> Void
    @State private var decided: InviteDecision?

    enum InviteDecision {
        case accepted, declined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(theme.current.primary)
                Text(session.game)
                    .font(.headline)
                    .foregroundStyle(theme.current.text)
                Spacer()
                Text(session.startsAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(theme.current.textSecondary)
            }
            Text("\(hostName) · \(session.mode) · \(SessionEngine.occupancyText(session))")
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
            if !session.comment.isEmpty {
                Text(session.comment)
                    .font(.subheadline)
                    .foregroundStyle(theme.current.text)
            }
            if let decided {
                // Системное сообщение после решения.
                Text(decided == .accepted ? String(localized: "session.accepted.system") : String(localized: "session.declined.system"))
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.current.surfaceSecondary, in: .capsule)
                    .accessibilityLabel(String(localized: "chats.system"))
            } else {
                HStack(spacing: 10) {
                    Button {
                        Haptics.success()
                        decided = .accepted
                        onAccept()
                    } label: {
                        Text(String(localized: "session.accept"))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.current.success)
                    Button {
                        Haptics.selection()
                        decided = .declined
                        onDecline()
                    } label: {
                        Text(String(localized: "session.decline"))
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.current.danger)
                }
            }
        }
        .padding(14)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.game), \(hostName)")
    }
}

#Preview {
    CreateSessionSheet()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

#Preview("Invite") {
    SessionInviteCard(session: PreviewData.session, hostName: "Neo", onAccept: {}, onDecline: {})
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
        .padding()
        .background(.black)
}

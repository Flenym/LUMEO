// Lumeo — Sources/Features/Sessions/SessionDetailView.swift
// Детальный экран Session: участники с готовностью (toggle), kick для создателя,
// start / finish / cancel по графу SessionEngine, таймер до старта.
// Открывается из баннера, чата и deep-link lumeo://session/:id.

import SwiftUI

// MARK: - SessionDetailView

struct SessionDetailView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State var session: GameSession
    /// Имена участников (userID → displayName). Превью — из PreviewData.
    @State var names: [UUID: String] = SessionDetailView.previewNames()
    @State private var kickCandidate: SessionParticipant?
    @State private var showCancel = false

    private var isCreator: Bool { session.hostID == PreviewData.me.id }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.game)
                            .font(.title2.bold())
                            .foregroundStyle(theme.current.text)
                        Spacer()
                        Text(SessionEngine.occupancyText(session))
                            .font(.headline)
                            .foregroundStyle(theme.current.secondary)
                    }
                    HStack(spacing: 8) {
                        Text(session.mode)
                            .font(.subheadline)
                            .foregroundStyle(theme.current.textSecondary)
                        Text("·")
                            .foregroundStyle(theme.current.textSecondary)
                        if session.startsAt > .now {
                            Text(timerInterval: Date()...session.startsAt, countsDown: true)
                                .font(.subheadline)
                                .foregroundStyle(theme.current.secondary)
                        } else {
                            Text(String(localized: "session.live"))
                                .font(.subheadline.bold())
                                .foregroundStyle(theme.current.danger)
                        }
                    }
                    if !session.comment.isEmpty {
                        Text(session.comment)
                            .font(.subheadline)
                            .foregroundStyle(theme.current.text)
                    }
                    Text(stateTitle)
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.current.surfaceSecondary, in: .capsule)
                }
                .padding(.vertical, 4)
            }

            Section(String(localized: "session.participants")) {
                if session.participants.isEmpty {
                    Text(String(localized: "session.participants.hint"))
                        .font(.subheadline)
                        .foregroundStyle(theme.current.textSecondary)
                } else {
                    ForEach(session.participants, id: \.userID) { participant in
                        ParticipantRow(
                            participant: participant,
                            name: names[participant.userID] ?? String(localized: "session.player"),
                            isCreator: isCreator,
                            isMe: participant.userID == PreviewData.me.id,
                            onToggleReady: { toggleReady(participant) },
                            onKick: { kickCandidate = participant }
                        )
                    }
                }
            }

            Section {
                // Start — только из waiting/ready при набранном минимуме.
                if SessionEngine.canStart(session) {
                    Button {
                        transition(to: .ready)
                        transition(to: .live)
                    } label: {
                        Label(String(localized: "session.start"), systemImage: "play.fill")
                    }
                    .tint(theme.current.success)
                }
                if session.state == .live || session.state == .paused {
                    Button {
                        transition(to: .finished)
                    } label: {
                        Label(String(localized: "session.finish"), systemImage: "flag.fill")
                    }
                    .tint(theme.current.primary)
                }
                if SessionEngine.canTransition(from: session.state, to: .cancelled) {
                    Button(role: .destructive) {
                        showCancel = true
                    } label: {
                        Label(String(localized: "session.cancel"), systemImage: "xmark.circle")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(session.game)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(String(localized: "session.cancel.confirm"), isPresented: $showCancel, titleVisibility: .visible) {
            Button(String(localized: "session.cancel"), role: .destructive) {
                transition(to: .cancelled)
                dismiss()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            String(localized: "session.kick.confirm"),
            isPresented: Binding(get: { kickCandidate != nil }, set: { if !$0 { kickCandidate = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "session.kick"), role: .destructive) {
                if let candidate = kickCandidate { kick(candidate) }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Mutations

    private var stateTitle: String {
        String(localized: "session.state.\(session.state.rawValue)")
    }

    private func toggleReady(_ participant: SessionParticipant) {
        guard let i = session.participants.firstIndex(where: { $0.userID == participant.userID }) else { return }
        Haptics.selection()
        let current = session.participants[i].state
        session.participants[i].state = (current == .ready) ? .accepted : .ready
        // TODO(backend): PATCH /api/v1/sessions/{id}/ready.
    }

    /// Kick — только создатель, только чужих участников.
    private func kick(_ participant: SessionParticipant) {
        guard isCreator, participant.userID != PreviewData.me.id else { return }
        Haptics.warning()
        session.participants.removeAll(where: { $0.userID == participant.userID })
        session.slotsTaken = max(1, session.slotsTaken - 1)
        // TODO(backend): POST /api/v1/sessions/{id}/kick {userId}.
        kickCandidate = nil
    }

    private func transition(to state: SessionState) {
        guard SessionEngine.canTransition(from: session.state, to: state) else {
            Haptics.error()
            return
        }
        Haptics.medium()
        session.state = state
        // TODO(backend): POST /api/v1/sessions/{id}/transition {to}.
        Task { await APIClient.shared.transitionSession(id: session.id, to: state) }
    }

    static func previewNames() -> [UUID: String] {
        var names: [UUID: String] = [PreviewData.me.id: "Вы"]
        for friend in PreviewData.friends {
            names[friend.user.id] = friend.user.displayName
        }
        return names
    }
}

// MARK: - ParticipantRow

struct ParticipantRow: View {
    @Environment(ThemeManager.self) private var theme
    var participant: SessionParticipant
    var name: String
    var isCreator: Bool
    var isMe: Bool
    var onToggleReady: () -> Void
    var onKick: () -> Void

    private var isReady: Bool {
        participant.state == .ready || participant.state == .accepted
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.current.surfaceSecondary)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(name.prefix(1)))
                        .foregroundStyle(theme.current.text)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(name)
                        .foregroundStyle(theme.current.text)
                    if participant.role == .owner {
                        Text(String(localized: "session.host"))
                            .font(.caption2.bold())
                            .foregroundStyle(theme.current.warning)
                    }
                }
                Text(isReady ? "✓ \(String(localized: "session.ready"))" : "… \(String(localized: "session.notReady"))")
                    .font(.caption)
                    .foregroundStyle(isReady ? theme.current.success : theme.current.textSecondary)
            }
            Spacer()
            if isMe || isCreator {
                Button(action: onToggleReady) {
                    Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isReady ? theme.current.success : theme.current.textSecondary)
                }
                .accessibilityLabel(String(localized: "session.ready.toggle"))
            }
            if isCreator, !isMe {
                Button(action: onKick) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundStyle(theme.current.danger)
                }
                .accessibilityLabel(String(localized: "session.kick"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(isReady ? String(localized: "session.ready") : String(localized: "session.notReady"))")
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: PreviewData.session)
    }
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
}

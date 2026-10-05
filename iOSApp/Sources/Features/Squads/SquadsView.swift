// Lumeo — Sources/Features/Squads/SquadsView.swift
// Squads до 200 участников: Owner / Admin / Member, Squad Level / XP / Streak,
// кнопка Invite all. Групповой чат Squad = ChatKind.squad.
// XP/ранг — XPEngine (паритет backend), награды — превью бейджей.

import SwiftUI

// MARK: - SquadsView

struct SquadsView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var squads: [Squad] = PreviewData.squads

    var body: some View {
        NavigationStack {
            List(squads) { squad in
                NavigationLink {
                    SquadDetailView(squad: squad)
                } label: {
                    SquadRow(squad: squad)
                }
                .listRowBackground(theme.current.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "tab.squads"))
            .refreshable {
                // TODO(backend): GET /api/v1/squads через APIClient.
                squads = PreviewData.squads
            }
        }
    }
}

// MARK: - SquadRow

struct SquadRow: View {
    @Environment(ThemeManager.self) private var theme
    var squad: Squad

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(theme.current.surfaceSecondary)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(squad.name.prefix(1)))
                            .font(.headline)
                            .foregroundStyle(theme.current.text)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(squad.name)
                        .font(.headline)
                        .foregroundStyle(theme.current.text)
                    // Онлайн-счётчик «3/5 online».
                    Text("\(onlineCount)/\(squad.members.count) \(String(localized: "squads.online")) · Lv \(squad.level)")
                        .font(.caption)
                        .foregroundStyle(theme.current.textSecondary)
                }
                Spacer()
                // Streak — только за реальные совместные Session (см. StreakEngine).
                Label("\(squad.streakDays)", systemImage: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.current.primary)
                    .accessibilityLabel("\(String(localized: "squads.streak")): \(squad.streakDays)")
            }
            // XP-прогресс до следующего уровня.
            ProgressView(value: XPEngine.progress(xp: squad.xp))
                .tint(theme.current.primary)
                .accessibilityLabel("\(String(localized: "squads.level")) \(squad.level)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(squad.name), \(onlineCount)/\(squad.members.count)")
    }

    /// Онлайн-участники по lookup превью (прод — presence из WS).
    private var onlineCount: Int {
        let onlineIDs = Set(PreviewData.friends.filter { $0.user.isOnline }.map { $0.user.id })
        var count = squad.members.filter { onlineIDs.contains($0.userID) }.count
        // «Вы» — владелец/участник и онлайн.
        if squad.members.contains(where: { $0.userID == PreviewData.me.id }) {
            count += 1
        }
        return min(count, squad.members.count)
    }
}

// MARK: - SquadDetailView

struct SquadDetailView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    var squad: Squad
    @State private var showLeave = false
    @State private var inviteAllSent = false

    var body: some View {
        List {
            Section {
                SquadRow(squad: squad)
                // Squad XP bar + Level + ранг/дивизион + награды preview.
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Lv \(squad.level)")
                            .font(.headline)
                            .foregroundStyle(theme.current.text)
                        Text(XPEngine.rankDisplay(forLevel: squad.level))
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.current.primary)
                        Spacer()
                        Text("\(squad.xp) XP")
                            .font(.caption)
                            .foregroundStyle(theme.current.textSecondary)
                    }
                    ProgressView(value: XPEngine.progress(xp: squad.xp))
                        .tint(theme.current.primary)
                    // Награды preview (бейджи уровня).
                    HStack(spacing: 8) {
                        ForEach(rewardPreview, id: \.self) { badge in
                            Label(badge, systemImage: "medal.fill")
                                .font(.caption)
                                .foregroundStyle(theme.current.warning)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(String(localized: "squads.rewards")): \(rewardPreview.joined(separator: ", "))")
                }
                .padding(.vertical, 4)
            }
            Section(String(localized: "squads.members")) {
                ForEach(squad.members, id: \.userID) { member in
                    SquadMemberRow(member: member)
                }
            }
            Section {
                // Invite all: один инвайт всей пати в Session.
                Button {
                    Haptics.sessionCreated()
                    inviteAllSent = true
                    // TODO(backend): POST /api/v1/sessions с invitedIDs = все участники.
                } label: {
                    Label(
                        inviteAllSent ? String(localized: "squads.inviteAll.sent") : String(localized: "squads.inviteAll"),
                        systemImage: "envelope.open.fill"
                    )
                }
                .tint(theme.current.primary)
                .frame(minHeight: 44)
                .disabled(inviteAllSent)
                Button(role: .destructive) {
                    showLeave = true
                } label: {
                    Label(
                        myRole == .owner ? String(localized: "squads.close") : String(localized: "squads.leave"),
                        systemImage: "door.left.hand.open"
                    )
                }
                .frame(minHeight: 44)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(squad.name)
        .confirmationDialog(
            myRole == .owner ? String(localized: "squads.close.confirm") : String(localized: "squads.leave.confirm"),
            isPresented: $showLeave, titleVisibility: .visible
        ) {
            Button(String(localized: "squads.leave"), role: .destructive) {
                // TODO(backend): POST /api/v1/squads/{id}/leave через APIClient.
                Task { await APIClient.shared.leaveSquad(id: squad.id) }
                dismiss()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    private var myRole: SquadRole {
        squad.members.first(where: { $0.userID == PreviewData.me.id })?.role ?? .member
    }

    /// Превью наград по уровню (бейджи).
    private var rewardPreview: [String] {
        switch squad.level {
        case ..<5: return ["🌱"]
        case 5..<10: return ["🌱", "🥉"]
        case 10..<20: return ["🌱", "🥉", "🥈"]
        default: return ["🌱", "🥉", "🥈", "🏆"]
        }
    }
}

// MARK: - SquadMemberRow

/// Участник с ролью Owner / Admin / Member.
struct SquadMemberRow: View {
    @Environment(ThemeManager.self) private var theme
    var member: SquadMember

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.current.surfaceSecondary)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(displayName.prefix(1)))
                        .foregroundStyle(theme.current.text)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .foregroundStyle(theme.current.text)
                Text(roleTitle)
                    .font(.caption)
                    .foregroundStyle(roleColor)
            }
            Spacer()
            if isOnline {
                Circle()
                    .fill(theme.current.success)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(String(localized: "status.online"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(roleTitle)")
    }

    private var displayName: String {
        if member.userID == PreviewData.me.id { return "Вы" }
        return PreviewData.friends.first(where: { $0.user.id == member.userID })?.user.displayName
            ?? String(localized: "session.player")
    }

    private var isOnline: Bool {
        if member.userID == PreviewData.me.id { return true }
        return PreviewData.friends.first(where: { $0.user.id == member.userID })?.user.isOnline ?? false
    }

    private var roleTitle: String {
        switch member.role {
        case .owner: String(localized: "squads.role.owner")
        case .admin: String(localized: "squads.role.admin")
        case .member: String(localized: "squads.role.member")
        }
    }

    private var roleColor: Color {
        switch member.role {
        case .owner: theme.current.warning
        case .admin: theme.current.secondary
        case .member: theme.current.textSecondary
        }
    }
}

#Preview {
    SquadsView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

#Preview("Detail") {
    NavigationStack {
        SquadDetailView(squad: PreviewData.squads[0])
    }
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
}

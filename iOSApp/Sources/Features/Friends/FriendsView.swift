// Lumeo — Sources/Features/Friends/FriendsView.swift
// Список друзей: фильтры Все / Онлайн / Свободны / Играют / Избранные;
// сортировки: активность / имя / lastSeen / частота / закреп / вручную.
// Свайпы: message / invite / profile. Профиль — bottom-sheet.
// Add-friend: username-поиск + QR + invite-link (ShareLink) + импорт контактов (stub с permissions).
// Повторный запрос — cooldown 24ч с таймером. Block/mute — меню.

import SwiftUI
import Contacts

// MARK: - FriendsFilter / FriendsSort

enum FriendsFilter: String, CaseIterable, Identifiable {
    case all, online, free, playing, favorites
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all: "friends.filter.all"
        case .online: "friends.filter.online"
        case .free: "friends.filter.free"
        case .playing: "friends.filter.playing"
        case .favorites: "friends.filter.favorites"
        }
    }
}

enum FriendsSort: String, CaseIterable, Identifiable {
    /// Активность (свежесть статуса) / имя / lastSeen / частота игр / закреп / вручную.
    case activity, name, lastSeen, frequency, pinned, manual
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .activity: "friends.sort.activity"
        case .name: "friends.sort.name"
        case .lastSeen: "friends.sort.lastSeen"
        case .frequency: "friends.sort.frequency"
        case .pinned: "friends.sort.pinned"
        case .manual: "friends.sort.manual"
        }
    }
}

// MARK: - FriendsView

struct FriendsView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var friends: [Friend] = PreviewData.friends
    @State private var filter: FriendsFilter = .all
    @State private var sort: FriendsSort = .activity
    @State private var query = ""
    @State private var showQR = false
    @State private var showAdd = false
    @State private var profileFriend: Friend?
    @State private var inviteFriend: Friend?
    @State private var blockCandidate: Friend?
    /// Cooldown повторных заявок: friendID → время последней отправки (24ч).
    @State private var sentRequests: [UUID: Date] = [:]
    // UITesting-стаб заявки (LumeoUITests, flow 2): результат → send → pending → accepted.
    @State private var uitestSelected = false
    @State private var uitestSent = false
    @State private var uitestAccepted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                if UITesting.isActive {
                    uitestRequestPanel
                }
                List(visible) { friend in
                    FriendRow(friend: friend, cooldown: cooldownRemaining(for: friend))
                        .listRowBackground(theme.current.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                profileFriend = friend
                            } label: {
                                Label(String(localized: "friends.profile"), systemImage: "person")
                            }
                            .tint(theme.current.secondary)
                            Button {
                                inviteFriend = friend
                            } label: {
                                Label(String(localized: "home.play"), systemImage: "gamecontroller")
                            }
                            .tint(theme.current.primary)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                togglePin(friend)
                            } label: {
                                Label(String(localized: "home.pin"), systemImage: "pin")
                            }
                            .tint(theme.current.secondary)
                            Button {
                                toggleMute(friend)
                            } label: {
                                Label(
                                    String(localized: "friends.mute"),
                                    systemImage: friend.isMuted ? "bell" : "bell.slash"
                                )
                            }
                            .tint(theme.current.warning)
                        }
                        .contextMenu {
                            Button { profileFriend = friend } label: {
                                Label(String(localized: "friends.profile"), systemImage: "person")
                            }
                            Button { toggleMute(friend) } label: {
                                Label(String(localized: "friends.mute"), systemImage: friend.isMuted ? "bell" : "bell.slash")
                            }
                            Button { toggleFavorite(friend) } label: {
                                Label(String(localized: "home.favorite"), systemImage: friend.isFavorite ? "star.slash" : "star")
                            }
                            Button(role: .destructive) { blockCandidate = friend } label: {
                                Label(String(localized: "friends.block"), systemImage: "nosign")
                            }
                        }
                        .onTapGesture {
                            profileFriend = friend
                        }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(theme.current.background)
            }
            .background(theme.current.background)
            .navigationTitle(String(localized: "tab.friends"))
            .searchable(text: $query, prompt: String(localized: "friends.search"))
            .refreshable {
                await reload()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(FriendsSort.allCases) { option in
                            Button(String(localized: "\(option.titleKey)")) {
                                Haptics.selection()
                                sort = option
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .tint(theme.current.primary)
                    .accessibilityLabel(String(localized: "friends.sort"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            Haptics.selection()
                            showQR = true
                        } label: {
                            Image(systemName: "qrcode")
                        }
                        .tint(theme.current.primary)
                        .accessibilityLabel(String(localized: "friends.qr.title"))
                        Button {
                            Haptics.selection()
                            showAdd = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        .tint(theme.current.primary)
                        .accessibilityLabel(String(localized: "friends.add"))
                    }
                }
            }
            .sheet(isPresented: $showQR) {
                QRInviteSheet()
            }
            .sheet(isPresented: $showAdd) {
                AddFriendSheet(sentRequests: $sentRequests)
            }
            .sheet(item: $profileFriend) { friend in
                FriendProfileSheet(friend: friend, cooldown: cooldownRemaining(for: friend))
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $inviteFriend) { friend in
                CreateSessionSheet(prefilledFriend: friend)
            }
            .confirmationDialog(
                String(localized: "friends.block.confirm"),
                isPresented: Binding(get: { blockCandidate != nil }, set: { if !$0 { blockCandidate = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "friends.block"), role: .destructive) {
                    if let friend = blockCandidate { block(friend) }
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            }
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FriendsFilter.allCases) { option in
                    Button {
                        Haptics.selection()
                        filter = option
                    } label: {
                        Text(String(localized: "\(option.titleKey)"))
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                filter == option ? theme.current.primary : theme.current.surface,
                                in: .capsule
                            )
                            .foregroundStyle(filter == option ? .white : theme.current.text)
                    }
                    .accessibilityLabel(String(localized: "\(option.titleKey)"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - UITesting request stub (flow 2)

    /// Детерминированный стаб: поиск → результат friend_two → send → pending,
    /// через ~1.5с стаб-собеседник принимает → accepted. Только с `--uitesting`.
    private var uitestRequestPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "friends.search"), text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("friends.search")
            if !query.isEmpty && !uitestSelected {
                Button {
                    Haptics.selection()
                    uitestSelected = true
                } label: {
                    HStack {
                        Text("@friend_two")
                            .foregroundStyle(theme.current.text)
                        Spacer()
                        Text(String(localized: "friends.add"))
                            .font(.caption)
                            .foregroundStyle(theme.current.primary)
                    }
                    .padding(10)
                    .background(theme.current.surface, in: .rect(cornerRadius: 12))
                }
                .accessibilityIdentifier("friends.search.result")
            }
            if uitestSelected && !uitestSent {
                Button(String(localized: "friends.request.send")) {
                    Haptics.selection()
                    uitestSent = true
                    // Стаб-собеседник принимает заявку.
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        uitestAccepted = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.current.primary)
                .accessibilityIdentifier("friends.request.send")
            }
            if uitestSent {
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(theme.current.warning)
                    .accessibilityIdentifier("friends.request.pending")
            }
            if uitestAccepted {
                Text("Accepted ✓")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.success)
                    .accessibilityIdentifier("friends.request.accepted")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Filtering / sorting

    private var visible: [Friend] {
        var list = friends
        switch filter {
        case .all: break
        case .online: list = list.filter { $0.user.isOnline }
        case .free: list = list.filter { StatusEngine.effectiveAvailability(status: $0.user.status) == .green }
        case .playing: list = list.filter { $0.user.isPlaying }
        case .favorites: list = list.filter { $0.isFavorite }
        }
        if !query.isEmpty {
            list = list.filter {
                $0.user.username.localizedCaseInsensitiveContains(query)
                    || $0.user.displayName.localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .activity:
            list.sort { $0.user.status.updatedAt > $1.user.status.updatedAt }
        case .name:
            list.sort { $0.user.displayName < $1.user.displayName }
        case .lastSeen:
            list.sort {
                ($0.user.lastSeenAt ?? .distantPast) > ($1.user.lastSeenAt ?? .distantPast)
            }
        case .frequency:
            list.sort { $0.playFrequency > $1.playFrequency }
        case .pinned:
            list.sort {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.user.status.updatedAt > $1.user.status.updatedAt
            }
        case .manual:
            list.sort { $0.manualOrder < $1.manualOrder }
        }
        return list
    }

    // MARK: - Cooldown (24ч на повторную заявку)

    static let requestCooldown: TimeInterval = 24 * 60 * 60

    private func cooldownRemaining(for friend: Friend) -> TimeInterval? {
        guard let sent = sentRequests[friend.id] else { return nil }
        let left = Self.requestCooldown - Date().timeIntervalSince(sent)
        return left > 0 ? left : nil
    }

    // MARK: - Mutations

    private func toggleMute(_ friend: Friend) {
        guard let i = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        Haptics.selection()
        friends[i].isMuted.toggle()
    }

    private func togglePin(_ friend: Friend) {
        guard let i = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        Haptics.selection()
        friends[i].isPinned.toggle()
    }

    private func toggleFavorite(_ friend: Friend) {
        guard let i = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        Haptics.selection()
        friends[i].isFavorite.toggle()
    }

    private func block(_ friend: Friend) {
        Haptics.warning()
        friends.removeAll(where: { $0.id == friend.id })
        // TODO(backend): POST /api/v1/users/{id}/block.
        Task { await APIClient.shared.blockUser(id: friend.user.id) }
        blockCandidate = nil
    }

    private func reload() async {
        // TODO(backend): GET /api/v1/friends через APIClient.
        try? await Task.sleep(for: .seconds(0.6))
        friends = PreviewData.friends
    }
}

// MARK: - FriendRow

struct FriendRow: View {
    @Environment(ThemeManager.self) private var theme
    var friend: Friend
    var cooldown: TimeInterval?

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(theme.current.surfaceSecondary)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(String(friend.user.displayName.prefix(1)))
                            .foregroundStyle(theme.current.text)
                    }
                Circle()
                    .fill(friend.user.isOnline ? theme.current.success : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay { Circle().stroke(theme.current.surface, lineWidth: 2) }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(friend.user.displayName)
                        .foregroundStyle(theme.current.text)
                    if friend.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.current.warning)
                            .accessibilityLabel(String(localized: "home.favorite"))
                    }
                    if friend.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.current.textSecondary)
                            .accessibilityLabel(String(localized: "friends.mute"))
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
                    .lineLimit(1)
                if let left = cooldown {
                    Text(cooldownText(left))
                        .font(.caption2)
                        .foregroundStyle(theme.current.warning)
                }
            }
            Spacer()
            // «Notify when friend becomes available» — колокольчик только у избранных.
            if friend.isFavorite {
                Image(systemName: friend.notifyWhenAvailable ? "bell.badge.fill" : "bell")
                    .foregroundStyle(theme.current.secondary)
                    .accessibilityLabel(String(localized: "friends.notify"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.user.displayName), \(subtitle)")
    }

    private var subtitle: String {
        if friend.user.isPlaying, let game = friend.user.currentGame {
            return "🎮 \(game)"
        }
        return friend.user.status.text.isEmpty
            ? StatusEngine.lastSeenText(lastSeenAt: friend.user.lastSeenAt, isOnline: friend.user.isOnline, privacy: .recent)
            : friend.user.status.text
    }

    private func cooldownText(_ left: TimeInterval) -> String {
        let hours = Int(ceil(left / 3600))
        return "\(String(localized: "friends.cooldown")) · \(hours)ч"
    }
}

// MARK: - FriendProfileSheet (bottom-sheet)

/// Профиль друга: статус, игра, действия (message/invite/notify/mute/block).
struct FriendProfileSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    var friend: Friend
    var cooldown: TimeInterval? = nil
    @State private var notifyOn = false
    @State private var showInvite = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Circle()
                    .fill(theme.current.surfaceSecondary)
                    .frame(width: 84, height: 84)
                    .overlay {
                        Text(String(friend.user.displayName.prefix(1)))
                            .font(.largeTitle.bold())
                            .foregroundStyle(theme.current.text)
                    }
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Text(friend.user.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(theme.current.text)
                    Text("@\(friend.user.username)")
                        .font(.subheadline)
                        .foregroundStyle(theme.current.textSecondary)
                    Text(friend.user.status.text)
                        .font(.subheadline)
                        .foregroundStyle(theme.current.text)
                    if let game = friend.user.currentGame {
                        Text("🎮 \(game)")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondary)
                    }
                    Text(StatusEngine.lastSeenText(lastSeenAt: friend.user.lastSeenAt, isOnline: friend.user.isOnline, privacy: .recent))
                        .font(.caption)
                        .foregroundStyle(theme.current.textSecondary)
                }
                if friend.isFavorite {
                    Toggle(String(localized: "friends.notify"), isOn: $notifyOn)
                        .tint(theme.current.primary)
                }
                if let left = cooldown {
                    Text("\(String(localized: "friends.cooldown")) · \(Int(ceil(left / 3600)))ч")
                        .font(.caption)
                        .foregroundStyle(theme.current.warning)
                }
                HStack(spacing: 12) {
                    Button {
                        Haptics.play()
                        showInvite = true
                    } label: {
                        Label(String(localized: "home.play"), systemImage: "gamecontroller.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.current.primary)
                    .disabled(cooldown != nil)
                    Button(String(localized: "tab.chats")) {
                        Haptics.selection()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.current.secondary)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.current.background)
            .navigationTitle(friend.user.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showInvite) {
                CreateSessionSheet(prefilledFriend: friend)
            }
            .onAppear { notifyOn = friend.notifyWhenAvailable }
        }
        .tint(theme.current.primary)
        .preferredColorScheme(.dark)
    }
}

// MARK: - AddFriendSheet

/// Добавление друга: username-поиск + QR + invite-link + импорт контактов (stub).
struct AddFriendSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var sentRequests: [UUID: Date]
    @State private var query = ""
    @State private var contactsAccess: String = "unknown"
    @State private var inviteURL = URL(string: "https://lumeo.example/invite/you")!

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "friends.add.search")) {
                    TextField(String(localized: "friends.search"), text: $query)
                        .textInputAutocapitalization(.never)
                    ForEach(results) { friend in
                        AddFriendRow(friend: friend, sentAt: sentRequests[friend.id]) {
                            sendRequest(to: friend)
                        }
                    }
                }
                Section(String(localized: "friends.add.share")) {
                    ShareLink(item: inviteURL) {
                        Label(String(localized: "friends.add.link"), systemImage: "link")
                    }
                    .tint(theme.current.primary)
                    Button {
                        // QR — отдельный sheet из FriendsView.
                    } label: {
                        Label(String(localized: "friends.qr.title"), systemImage: "qrcode")
                    }
                    .tint(theme.current.primary)
                }
                Section(String(localized: "friends.add.contacts")) {
                    // Stub: реальный импорт — CNContactStore.requestAccess + enumerateContacts (Фаза B),
                    // ключ NSContactsUsageDescription в Info.plist обязателен.
                    Button {
                        requestContactsAccess()
                    } label: {
                        Label(String(localized: "friends.add.contacts.import"), systemImage: "person.crop.circle.badge.plus")
                    }
                    .tint(theme.current.primary)
                    Text("\(String(localized: "friends.add.contacts.status")): \(contactsAccess)")
                        .font(.caption)
                        .foregroundStyle(theme.current.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "friends.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
            .searchable(text: $query, prompt: String(localized: "friends.search"))
        }
        .tint(theme.current.primary)
        .preferredColorScheme(.dark)
    }

    private var results: [Friend] {
        guard !query.isEmpty else { return Array(PreviewData.friends.prefix(3)) }
        return PreviewData.friends.filter {
            $0.user.username.localizedCaseInsensitiveContains(query)
                || $0.user.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private func sendRequest(to friend: Friend) {
        Haptics.success()
        sentRequests[friend.id] = .now
        // TODO(backend): POST /api/v1/friends/requests {username}.
        Task { await APIClient.shared.sendFriendRequest(username: friend.user.username) }
    }

    private func requestContactsAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            Task { @MainActor in
                contactsAccess = granted ? "granted" : "denied"
                Haptics.selection()
            }
        }
    }
}

// MARK: - AddFriendRow

struct AddFriendRow: View {
    @Environment(ThemeManager.self) private var theme
    var friend: Friend
    var sentAt: Date?
    var onSend: () -> Void

    var body: some View {
        HStack {
            Text(friend.user.displayName)
                .foregroundStyle(theme.current.text)
            Spacer()
            if let sent = sentAt, Date().timeIntervalSince(sent) < FriendsView.requestCooldown {
                let hours = Int(ceil((FriendsView.requestCooldown - Date().timeIntervalSince(sent)) / 3600))
                Text("\(hours)ч")
                    .font(.caption)
                    .foregroundStyle(theme.current.warning)
                    .accessibilityLabel("\(String(localized: "friends.cooldown")) · \(hours)ч")
            } else {
                Button(String(localized: "friends.add")) {
                    onSend()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.current.primary)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - QRInviteSheet

/// QR-приглашение в друзья (заглушка: генерация кода — Фаза B, backend /api/v1/invites).
struct QRInviteSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.current.surfaceSecondary)
                    .frame(width: 220, height: 220)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 100))
                            .foregroundStyle(theme.current.textSecondary)
                    }
                    .accessibilityHidden(true)
                Text(String(localized: "friends.qr.hint"))
                    .font(.subheadline)
                    .foregroundStyle(theme.current.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.current.background)
            .navigationTitle(String(localized: "friends.qr.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
        .tint(theme.current.primary)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    FriendsView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

#Preview("Profile") {
    FriendProfileSheet(friend: PreviewData.friends[0])
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

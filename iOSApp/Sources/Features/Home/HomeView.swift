// Lumeo — Sources/Features/Home/HomeView.swift
// Home отвечает на вопрос «С кем поиграть сейчас».
// Мой аватар/статус/online сверху; секции Кто свободен / Кто играет / Кто позже.
// Карточки 2 в ряд; long-press drag для reorder/pin, закрепы сверху.
// Поиск, фильтры-чипы, pull-to-refresh, empty-state, скелетоны.
// Notify-when-available — только для избранных.

import SwiftUI

// MARK: - HomeFilter

enum HomeFilter: String, CaseIterable, Identifiable {
    case all, free, playing, later
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all: "home.filter.all"
        case .free: "home.freeNow"
        case .playing: "home.playing"
        case .later: "home.later"
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var friends: [Friend] = PreviewData.friends
    @State private var query = ""
    @State private var filter: HomeFilter = .all
    @State private var isLoading = true
    @State private var showCreateSession = false
    @State private var inviteFriend: Friend?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    myStatusHeader
                    filterChips
                    if isLoading {
                        skeletonGrid
                    } else if filteredSections.flatMap(\.friends).isEmpty {
                        HomeEmptyState(query: query)
                    } else {
                        if !pinned.isEmpty {
                            section(title: String(localized: "home.pinned"), friends: pinned)
                        }
                        ForEach(filteredSections, id: \.title) { section in
                            if !section.friends.isEmpty {
                                self.section(title: section.title, friends: section.friends)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(theme.current.background)
            .navigationTitle(String(localized: "tab.home"))
            .searchable(text: $query, prompt: String(localized: "friends.search"))
            .refreshable {
                await reload()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        showCreateSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(theme.current.primary)
                    .accessibilityLabel(String(localized: "session.create"))
                }
            }
            .sheet(isPresented: $showCreateSession) {
                CreateSessionSheet()
            }
            .sheet(item: $inviteFriend) { friend in
                CreateSessionSheet(prefilledFriend: friend)
            }
            .task {
                // Скелетон первого экрана (~0.8с), дальше — кэш/превью.
                try? await Task.sleep(for: .seconds(0.8))
                isLoading = false
            }
        }
    }

    // MARK: - My status header

    private var myStatusHeader: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(theme.current.surfaceSecondary)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text("Вы")
                            .font(.headline)
                            .foregroundStyle(theme.current.text)
                    }
                Circle()
                    .fill(theme.current.success)
                    .frame(width: 16, height: 16)
                    .overlay { Circle().stroke(theme.current.background, lineWidth: 3) }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(PreviewData.me.displayName)
                    .font(.headline)
                    .foregroundStyle(theme.current.text)
                Text("🟢 \(String(localized: "status.green"))")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.textSecondary)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(theme.current.textSecondary)
            }
            .accessibilityLabel(String(localized: "settings.title"))
        }
        .padding(14)
        .background(theme.current.surface, in: .rect(cornerRadius: 18))
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeFilter.allCases) { option in
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
            .padding(.vertical, 2)
        }
    }

    // MARK: - Sections

    private struct HomeSection: Identifiable {
        var id: String { title }
        var title: String
        var friends: [Friend]
    }

    private var filteredSections: [HomeSection] {
        let searched = search(friends)
        let free = searched.filter { !$0.isPinned && StatusEngine.effectiveAvailability(status: $0.user.status) == .green && !$0.user.isPlaying }
        let playing = searched.filter { !$0.isPinned && $0.user.isPlaying }
        let later = searched.filter { !$0.isPinned && StatusEngine.effectiveAvailability(status: $0.user.status) == .yellow }
        switch filter {
        case .all:
            return [
                HomeSection(title: String(localized: "home.freeNow"), friends: free),
                HomeSection(title: String(localized: "home.playing"), friends: playing),
                HomeSection(title: String(localized: "home.later"), friends: later),
            ]
        case .free:
            return [HomeSection(title: String(localized: "home.freeNow"), friends: free)]
        case .playing:
            return [HomeSection(title: String(localized: "home.playing"), friends: playing)]
        case .later:
            return [HomeSection(title: String(localized: "home.later"), friends: later)]
        }
    }

    private func section(title: String, friends: [Friend]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(theme.current.text)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(friends) { friend in
                    FriendCard(
                        friend: friend,
                        onTogglePin: { togglePin(friend) },
                        onToggleFavorite: { toggleFavorite(friend) },
                        onToggleNotify: { toggleNotify(friend) },
                        onPlay: { inviteFriend = friend }
                    )
                    // Long-press drag для reorder: удержание → перетаскивание на карточку.
                    .onLongPressGesture {
                        Haptics.medium()
                    }
                    .draggable(friend.id.uuidString) {
                        FriendCard(
                            friend: friend,
                            onTogglePin: {}, onToggleFavorite: {}, onToggleNotify: {}, onPlay: {}
                        )
                        .opacity(0.85)
                    }
                    .dropDestination(for: String.self) { ids, _ in
                        guard let dragged = ids.first else { return false }
                        move(draggedID: dragged, to: friend)
                        return true
                    }
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                FriendCardSkeleton()
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel(String(localized: "common.loading"))
    }

    // MARK: - Filtering / sorting / reorder

    /// Закрепы всегда сверху, затем онлайн, затем по свежести статуса.
    private var pinned: [Friend] {
        search(friends).filter { $0.isPinned }
    }

    private func search(_ list: [Friend]) -> [Friend] {
        guard !query.isEmpty else { return list }
        return list.filter {
            $0.user.username.localizedCaseInsensitiveContains(query)
                || $0.user.displayName.localizedCaseInsensitiveContains(query)
        }
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
        if !friends[i].isFavorite { friends[i].notifyWhenAvailable = false }
    }

    private func toggleNotify(_ friend: Friend) {
        guard let i = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        Haptics.selection()
        friends[i].notifyWhenAvailable.toggle()
    }

    /// Reorder: перетащенная карточка встаёт на место целевой.
    private func move(draggedID: String, to target: Friend) {
        guard let from = friends.firstIndex(where: { $0.id.uuidString == draggedID }),
              let to = friends.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        Haptics.medium()
        let item = friends.remove(at: from)
        friends.insert(item, at: to)
        for i in friends.indices { friends[i].manualOrder = i }
    }

    private func reload() async {
        Haptics.selection()
        isLoading = true
        // TODO(backend): GET /api/v1/friends + statuses через APIClient.
        try? await Task.sleep(for: .seconds(0.6))
        friends = PreviewData.friends
        isLoading = false
    }
}

// MARK: - FriendCard

/// Карточка 2-в-ряд: аватар с online dot + цвет статуса, игра,
/// «изменено X мин», кнопка «Поиграть». Notify-bell — только у избранных.
struct FriendCard: View {
    @Environment(ThemeManager.self) private var theme
    var friend: Friend
    var onTogglePin: () -> Void
    var onToggleFavorite: () -> Void
    var onToggleNotify: () -> Void
    var onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(theme.current.surfaceSecondary)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String(friend.user.displayName.prefix(1)))
                                .font(.headline)
                                .foregroundStyle(theme.current.text)
                        }
                    Circle()
                        .fill(friend.user.isOnline ? theme.current.success : Color.gray)
                        .frame(width: 12, height: 12)
                        .overlay { Circle().stroke(theme.current.surface, lineWidth: 2) }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(friend.user.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.current.text)
                            .lineLimit(1)
                        if friend.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(theme.current.secondary)
                                .accessibilityLabel(String(localized: "home.pinned"))
                        }
                    }
                    Text("@\(friend.user.username)")
                        .font(.caption)
                        .foregroundStyle(theme.current.textSecondary)
                }
                Spacer()
                // Notify-when-available — колокольчик ТОЛЬКО у избранных.
                if friend.isFavorite {
                    Button(action: onToggleNotify) {
                        Image(systemName: friend.notifyWhenAvailable ? "bell.badge.fill" : "bell")
                            .foregroundStyle(theme.current.secondary)
                    }
                    .accessibilityLabel(String(localized: "friends.notify"))
                    .accessibilityValue(friend.notifyWhenAvailable ? String(localized: "common.on") : String(localized: "common.off"))
                }
            }
            Text(statusLine)
                .font(.caption)
                .foregroundStyle(statusColor)
                .lineLimit(1)
            if let game = friend.user.currentGame {
                Text("🎮 \(game)")
                    .font(.caption)
                    .foregroundStyle(theme.current.secondary)
                    .lineLimit(1)
            }
            Text("изм. \(friend.user.status.updatedAt, style: .relative)")
                .font(.caption2)
                .foregroundStyle(theme.current.textSecondary)
                .accessibilityLabel("\(String(localized: "home.updated")) \(friend.user.status.updatedAt, style: .relative)")
            Button {
                Haptics.play()
                onPlay()
            } label: {
                Text(String(localized: "home.play"))
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.current.primary, in: .rect(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("\(String(localized: "home.play")): \(friend.user.displayName)")
        }
        .padding(12)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.6), lineWidth: 1.5)
        }
        .contextMenu {
            Button(action: onTogglePin) {
                Label(
                    friend.isPinned ? String(localized: "home.unpin") : String(localized: "home.pin"),
                    systemImage: "pin"
                )
            }
            Button(action: onToggleFavorite) {
                Label(String(localized: "home.favorite"), systemImage: "star")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(friend.user.displayName), \(statusLine)")
    }

    private var statusColor: Color {
        StatusEngine.effectiveAvailability(status: friend.user.status).color(in: theme.current)
    }

    private var statusLine: String {
        let availability = StatusEngine.effectiveAvailability(status: friend.user.status)
        let key = switch availability {
        case .green: "status.green"
        case .yellow: "status.yellow"
        case .red: "status.red"
        }
        let base = String(localized: "\(key)")
        return friend.user.status.text.isEmpty ? base : "\(base) · \(friend.user.status.text)"
    }
}

// MARK: - FriendCardSkeleton

struct FriendCardSkeleton: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(theme.current.surfaceSecondary).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.current.surfaceSecondary).frame(width: 80, height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(theme.current.surfaceSecondary).frame(width: 56, height: 10)
                }
            }
            RoundedRectangle(cornerRadius: 4).fill(theme.current.surfaceSecondary).frame(height: 12)
            RoundedRectangle(cornerRadius: 10).fill(theme.current.surfaceSecondary).frame(height: 34)
        }
        .padding(12)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }
}

// MARK: - HomeEmptyState

struct HomeEmptyState: View {
    @Environment(ThemeManager.self) private var theme
    var query: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(theme.current.textSecondary)
                .accessibilityHidden(true)
            Text(String(localized: "home.empty.title"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            Text(query.isEmpty ? String(localized: "home.empty.hint") : String(localized: "home.empty.search"))
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

#Preview("Card") {
    FriendCard(
        friend: PreviewData.friends[0],
        onTogglePin: {}, onToggleFavorite: {}, onToggleNotify: {}, onPlay: {}
    )
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
    .padding()
    .background(.black)
}

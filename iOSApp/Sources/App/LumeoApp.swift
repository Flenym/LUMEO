// Lumeo — Sources/App/LumeoApp.swift
// Точка входа Main App. Bundle: com.lumeo.app · iOS 26+ · SwiftUI + Observation.
// Навигация: Home · Friends · Chats · Squads · Profile + центральная floating-кнопка «Поиграем?».
// Deep-links: lumeo://session/:id, lumeo://friend/:id.
// Health-check overlay: «Не удаётся подключиться к серверу» + «Повторить» (auto-retry exponential backoff).
// FaceID lock (опция, LocalAuthentication). Offline queue индикатор.

import SwiftUI
import LocalAuthentication

// MARK: - MainTab

enum MainTab: String, Hashable, CaseIterable {
    case home, friends, chats, squads, profile
}

// MARK: - DeepLink

/// Deep-link Main App: lumeo://session/:id, lumeo://friend/:id.
enum DeepLink: Hashable {
    case session(UUID)
    case friend(UUID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "lumeo" else { return nil }
        // Формы: lumeo://session/<uuid> и lumeo:session:<uuid> (host vs path).
        let host = url.host?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" }
        if host == "session", let id = parts.first.flatMap(UUID.init(uuidString:)) {
            self = .session(id)
        } else if host == "friend", let id = parts.first.flatMap(UUID.init(uuidString:)) {
            self = .friend(id)
        } else {
            return nil
        }
    }
}

// MARK: - LumeoApp

@main
struct LumeoApp: App {
    @State private var theme = ThemeManager()
    @State private var socket = WebSocketService()
    @State private var health: ServerHealth = .unknown
    @State private var healthAttempts = 0
    @State private var tab: MainTab = .home
    @State private var showCreateSession = false
    @State private var deepLink: DeepLink?
    @State private var deepSession: GameSession?
    @State private var deepFriend: Friend?
    @State private var offlineCount = 0
    /// FaceID lock: опция из Settings (ключ lumeo.faceIDEnabled).
    /// Stub: реальная привязка evaluatePolicy + Keychain — Фаза B.
    @AppStorage("lumeo.faceIDEnabled") private var faceIDEnabled = false
    @State private var locked = false
    /// Регистрация пройдена (онбординг register → verify → profile).
    /// `--reset-state` (UITests) сбрасывает флаг при старте.
    @AppStorage("lumeo.registered") private var registered = false

    init() {
        if UITesting.shouldReset {
            UserDefaults.standard.removeObject(forKey: "lumeo.registered")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                TabView(selection: $tab) {
                    Tab(String(localized: "tab.home"), systemImage: "house.fill", value: .home) {
                        HomeView()
                    }
                    Tab(String(localized: "tab.friends"), systemImage: "person.2.fill", value: .friends) {
                        FriendsView()
                    }
                    Tab(String(localized: "tab.chats"), systemImage: "message.fill", value: .chats) {
                        ChatListView()
                    }
                    Tab(String(localized: "tab.squads"), systemImage: "person.3.fill", value: .squads) {
                        SquadsView()
                    }
                    Tab(String(localized: "tab.profile"), systemImage: "person.crop.circle", value: .profile) {
                        ProfileView()
                    }
                }
                .tint(theme.current.primary)

                // MARK: Floating «Поиграем?» (Liquid Glass — точечно, только этот контрол)
                Button {
                    Haptics.play()
                    showCreateSession = true
                } label: {
                    Label(String(localized: "session.create"), systemImage: "gamecontroller.fill")
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                }
                .glassEffect(.regular.tint(theme.current.primary).interactive(), in: .capsule)
                .padding(.bottom, 76)
                .accessibilityIdentifier("session.create")
                .accessibilityLabel(String(localized: "session.create"))
                .accessibilityHint(String(localized: "session.create.hint"))
                .sensoryFeedback(.impact, trigger: showCreateSession)
            }
            .environment(theme)
            .environment(socket)
            .preferredColorScheme(.dark)
            // Локаль RU/EN (заглушка): реальный перевод — String Catalogs (.xcstrings),
            // выбор языка — в SettingsView. Здесь проброс для Preview и UI-тестов.
            .environment(\.locale, theme.locale)
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    // UITesting-полоса: детерминированное переключение табов
                    // (идентификаторы tab.* для LumeoUITests).
                    if UITesting.isActive {
                        MainTabStrip(tab: $tab)
                    }
                    if health == .unreachable {
                        HealthBanner {
                            healthAttempts = 0
                            Task { await checkHealthOnce() }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                    }
                    if offlineCount > 0 {
                        OfflineQueueBanner(count: offlineCount) {
                            Task { await APIClient.shared.replayQueue() }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .sheet(isPresented: $showCreateSession) {
                CreateSessionSheet()
            }
            .sheet(item: $deepSessionBinding) { session in
                NavigationStack {
                    SessionDetailView(session: session)
                }
            }
            .sheet(item: $deepFriendBinding) { friend in
                FriendProfileSheet(friend: friend)
            }
            .fullScreenCover(isPresented: $locked) {
                FaceLockView {
                    authenticate()
                }
            }
            // Онбординг поверх табов, пока не пройдена регистрация.
            .fullScreenCover(isPresented: Binding(
                get: { !registered },
                set: { if $0 { registered = false } }
            )) {
                OnboardingView {
                    registered = true
                }
            }
            .onOpenURL { url in
                guard let link = DeepLink(url: url) else { return }
                handleDeepLink(link)
            }
            .task {
                locked = faceIDEnabled
                socket.connect()
                await healthLoop()
            }
            .task {
                await pollOfflineQueue()
            }
        }
    }

    // MARK: - Deep links

    private var deepSessionBinding: Binding<GameSession?> {
        Binding(
            get: { deepSession },
            set: { deepSession = $0; if $0 == nil { deepLink = nil } }
        )
    }

    private var deepFriendBinding: Binding<Friend?> {
        Binding(
            get: { deepFriend },
            set: { deepFriend = $0; if $0 == nil { deepLink = nil } }
        )
    }

    private func handleDeepLink(_ link: DeepLink) {
        Haptics.selection()
        deepLink = link
        switch link {
        case .session(let id):
            tab = .chats
            deepSession = PreviewData.sessions.first(where: { $0.id == id })
                ?? GameSession(
                    id: id, hostID: PreviewData.me.id, game: "Valorant", mode: "5x5",
                    minPlayers: 2, slotsTotal: 5, slotsTaken: 1,
                    startsAt: .now.addingTimeInterval(3600), comment: "",
                    invitedIDs: [], state: .waiting
                )
        case .friend(let id):
            tab = .friends
            deepFriend = PreviewData.friends.first(where: { $0.user.id == id || $0.id == id })
        }
    }

    // MARK: - Health (exponential backoff auto-retry)

    /// Цикл: проверка → при провале backoff 2^N (cap 30с) → повтор. Успех сбрасывает счётчик.
    private func healthLoop() async {
        while true {
            await checkHealthOnce()
            if health == .ok {
                try? await Task.sleep(for: .seconds(60))
            } else {
                let delay = min(pow(2.0, Double(healthAttempts)), 30)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func checkHealthOnce() async {
        health = .checking
        let ok = await APIClient.shared.health()
        if ok {
            health = .ok
            healthAttempts = 0
        } else {
            health = .unreachable
            healthAttempts += 1
            Haptics.warning()
        }
    }

    // MARK: - Offline queue

    private func pollOfflineQueue() async {
        while true {
            offlineCount = APIClient.shared.queueCount
            try? await Task.sleep(for: .seconds(2))
        }
    }

    // MARK: - FaceID lock (stub)

    /// Разблокировка через LocalAuthentication. Stub: без Enclave-привязки (Фаза B).
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Симулятор без биометрии — пропускаем.
            locked = false
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "lock.reason")) { success, _ in
            Task { @MainActor in
                if success {
                    Haptics.success()
                    locked = false
                }
            }
        }
    }
}

// MARK: - MainTabStrip (UITesting)

/// Полоса переключения табов для UI-тестов. Видна только с `--uitesting`.
private struct MainTabStrip: View {
    @Binding var tab: MainTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(MainTab.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        tab = option
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityIdentifier("tab.\(option.rawValue)")
                }
            }
            .padding(6)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - HealthBanner

/// Офлайн-баннер: «Не удаётся подключиться к серверу» + «Повторить» (auto-retry идёт фоном).
struct HealthBanner: View {
    @Environment(ThemeManager.self) private var theme
    var retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(theme.current.warning)
                .accessibilityHidden(true)
            Text(String(localized: "health.unreachable"))
                .font(.subheadline)
                .foregroundStyle(theme.current.text)
            Spacer()
            Button(String(localized: "health.retry"), action: {
                Haptics.selection()
                retry()
            })
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            .controlSize(.small)
        }
        .padding(12)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "health.unreachable")). \(String(localized: "health.retry"))")
    }
}

// MARK: - OfflineQueueBanner

/// Индикатор офлайн-очереди: «Офлайн: N • Повторить отправку».
struct OfflineQueueBanner: View {
    @Environment(ThemeManager.self) private var theme
    var count: Int
    var retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.up.fill")
                .foregroundStyle(theme.current.secondary)
                .accessibilityHidden(true)
            Text("\(String(localized: "offline.queued")): \(count)")
                .font(.subheadline)
                .foregroundStyle(theme.current.text)
            Spacer()
            Button(String(localized: "health.retry"), action: {
                Haptics.selection()
                retry()
            })
            .buttonStyle(.bordered)
            .tint(theme.current.primary)
            .controlSize(.small)
        }
        .padding(12)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "offline.queued")): \(count)")
    }
}

// MARK: - FaceLockView

/// Экран блокировки FaceID (опция). Stub-разблокировка через LAContext.
struct FaceLockView: View {
    @Environment(ThemeManager.self) private var theme
    var unlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 72))
                .foregroundStyle(theme.current.primary)
                .accessibilityHidden(true)
            Text(String(localized: "lock.title"))
                .font(.title2.bold())
                .foregroundStyle(theme.current.text)
            Button(String(localized: "lock.unlock"), action: {
                Haptics.selection()
                unlock()
            })
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.current.background)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "lock.title"))
    }
}

#Preview {
    HealthBanner {}
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
        .padding()
        .background(.black)
}

#Preview("Offline") {
    OfflineQueueBanner(count: 3) {}
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
        .padding()
        .background(.black)
}

#Preview("Lock") {
    FaceLockView {}
        .environment(ThemeManager())
}

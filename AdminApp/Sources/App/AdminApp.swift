// Lumeo Admin — Sources/App/AdminApp.swift
// Точка входа Admin App. Bundle: com.lumeo.admin.
// Табы: Overview / Users / Moderation / Verification / Economy / Content / Analytics / Server.
// БЕЗОПАСНОСТЬ: публичного логина НЕТ. Устройство предрегистрировано (device pre-registered),
// admin-credential хранится в Keychain (заглушка ниже — заменить SecItem* в Xcode).

import SwiftUI

// MARK: - AdminCredentialStore (Keychain заглушка)

/// Dev-заглушка поверх UserDefaults.
/// TODO(security): заменить на Keychain kSecClassGenericPassword (SecItemAdd/CopyMatching),
/// привязка к deviceID + attestation; без credential — экран блокировки без формы логина.
enum AdminCredentialStore {
    private static let key = "admin.deviceCredential"

    static var hasCredential: Bool {
        UserDefaults.standard.string(forKey: key) != nil
    }

    static func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func provisionDemo() {
        if !hasCredential {
            UserDefaults.standard.set("PRE-REGISTERED-DEMO-CREDENTIAL", forKey: key)
        }
    }
}

// MARK: - AdminSession

@Observable
final class AdminSession {
    var isProvisioned: Bool = AdminCredentialStore.hasCredential
    var deviceID: String = "demo-device-001"
}

// MARK: - AdminApp

@main
struct AdminApp: App {
    @State private var session: AdminSession
    @State private var selection = 0

    /// UITests (`--uitesting`): пропускаем provision-экран, сразу табы.
    private static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    init() {
        // Provision ДО чтения hasCredential в AdminSession.init.
        if Self.isUITesting {
            AdminCredentialStore.provisionDemo()
        }
        _session = State(initialValue: AdminSession())
    }

    var body: some Scene {
        WindowGroup {
            if session.isProvisioned {
                TabView(selection: $selection) {
                    Tab("Overview", systemImage: "gauge.with.dots.needle.67percent", value: 0) { OverviewView() }
                    Tab("Users", systemImage: "person.2", value: 1) { UsersView() }
                    Tab("Moderation", systemImage: "shield", value: 2) { ModerationView() }
                    Tab("Verification", systemImage: "checkmark.seal", value: 3) { VerificationView() }
                    Tab("Economy", systemImage: "coins", value: 4) { EconomyView() }
                    Tab("Content", systemImage: "photo.stack", value: 5) { ContentView() }
                    Tab("Analytics", systemImage: "chart.bar", value: 6) { AnalyticsView() }
                    Tab("Server", systemImage: "server.rack", value: 7) { ServerView() }
                    Tab("Audit", systemImage: "list.bullet.rectangle", value: 8) { AuditView() }
                }
                .tint(.orange)
                .overlay(alignment: .top) {
                    // UITesting-полоса: детерминированное переключение табов
                    // (идентификаторы admin.tab.* для AdminUITests).
                    if Self.isUITesting {
                        AdminTabStrip(selection: $selection)
                    }
                }
            } else {
                // Нет credential — только статус + кнопка запроса (без публичного логина).
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                    Text("Device not provisioned")
                        .font(.headline)
                    Text("Ask the owner to pre-register this device. There is no public login.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Provision demo credential") {
                        AdminCredentialStore.provisionDemo()
                        session.isProvisioned = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
}

// MARK: - AdminTabStrip (UITesting)

/// Полоса переключения табов для UI-тестов. Видна только с `--uitesting`.
private struct AdminTabStrip: View {
    @Binding var selection: Int

    private let tabs: [(id: String, title: String)] = [
        ("admin.tab.overview", "Overview"),
        ("admin.tab.users", "Users"),
        ("admin.tab.moderation", "Moderation"),
        ("admin.tab.verification", "Verification"),
        ("admin.tab.economy", "Economy"),
        ("admin.tab.content", "Content"),
        ("admin.tab.analytics", "Analytics"),
        ("admin.tab.server", "Server"),
        ("admin.tab.audit", "Audit"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.id) { tab in
                    Button(tab.title) {
                        selection = tabs.firstIndex(where: { $0.id == tab.id }) ?? 0
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityIdentifier(tab.id)
                }
            }
            .padding(6)
        }
        .background(.ultraThinMaterial)
    }
}

#Preview {
    OverviewView()
        .preferredColorScheme(.dark)
}

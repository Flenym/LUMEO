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
    @State private var session = AdminSession()

    var body: some Scene {
        WindowGroup {
            if session.isProvisioned {
                TabView {
                    Tab("Overview", systemImage: "gauge.with.dots.needle.67percent") { OverviewView() }
                    Tab("Users", systemImage: "person.2") { UsersView() }
                    Tab("Moderation", systemImage: "shield") { ModerationView() }
                    Tab("Verification", systemImage: "checkmark.seal") { VerificationView() }
                    Tab("Economy", systemImage: "coins") { EconomyView() }
                    Tab("Content", systemImage: "photo.stack") { ContentView() }
                    Tab("Analytics", systemImage: "chart.bar") { AnalyticsView() }
                    Tab("Server", systemImage: "server.rack") { ServerView() }
                }
                .tint(.orange)
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

#Preview {
    OverviewView()
        .preferredColorScheme(.dark)
}

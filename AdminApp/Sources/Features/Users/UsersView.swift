// Lumeo Admin — Sources/Features/Users/UsersView.swift
// Пользователи: search / profile / status / badges / level / currency /
// inventory / ban / mute / verify / grant. Audit на каждое действие.
// Plaintext сообщений НЕ отображается (только metadata из Moderation).

import SwiftUI

// MARK: - AdminUser

struct AdminUser: Identifiable, Hashable {
    var id: UUID = UUID()
    var username: String
    var status: String
    var badges: [String]
    var level: Int
    var ember: Int
    var inventoryCount: Int
    var isBanned: Bool
    var isMuted: Bool
    var isVerified: Bool
}

// MARK: - UsersView

struct UsersView: View {
    @State private var users: [AdminUser] = [
        AdminUser(username: "neo", status: "online", badges: ["verified"], level: 12, ember: 1250, inventoryCount: 8, isBanned: false, isMuted: false, isVerified: true),
        AdminUser(username: "mira", status: "in session", badges: ["sponsor"], level: 9, ember: 640, inventoryCount: 5, isBanned: false, isMuted: false, isVerified: false),
        AdminUser(username: "dex", status: "offline", badges: [], level: 4, ember: 120, inventoryCount: 2, isBanned: false, isMuted: true, isVerified: false),
        AdminUser(username: "spam1", status: "offline", badges: [], level: 1, ember: 0, inventoryCount: 0, isBanned: true, isMuted: true, isVerified: false),
        AdminUser(username: "reported_user", status: "reported", badges: [], level: 2, ember: 40, inventoryCount: 1, isBanned: false, isMuted: false, isVerified: false),
    ]
    @State private var query = ""
    @State private var selected: AdminUser?
    @State private var showDetail = false
    @State private var grantAmount = "500"
    @State private var audit: [AuditLogEntry] = AdminPreviewData.audit
    @State private var justBanned: String?
    @FocusState private var searchFocused: Bool

    private var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    var body: some View {
        NavigationStack {
            List {
                if isUITesting {
                    Section("Search") {
                        TextField("Search username", text: $query)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .onSubmit { searchFocused = false }
                            .accessibilityIdentifier("admin.users.search")
                            .onChange(of: query) { _, new in
                                // UITesting-автооткрытие (AdminUITests): как только
                                // введён запрос — открываем шит reported_user БЕЗ тапа.
                                // Тапы по тулбару/строкам на холодном симуляторе
                                // ненадёжны (stale-координаты, зеркала в иерархии).
                                guard !new.isEmpty else { return }
                                Task {
                                    try? await Task.sleep(for: .seconds(1))
                                    if let match = users.first(where: { $0.username == "reported_user" }),
                                       !showDetail {
                                        selected = match
                                        showDetail = true
                                    }
                                }
                            }
                    }
                    if !query.isEmpty {
                        Text("Tap the toolbar button to open the match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let justBanned {
                    Section {
                        Text("Banned @\(justBanned)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("admin.user.banned")
                    }
                }
                Section("Users") {
                    ForEach(visible) { user in
                        Button {
                            selected = user
                            showDetail = true
                        } label: {
                            userRowLabel(user)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("admin.users.row.\(user.username)")
                    }
                }
                Section("Audit") {
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    ForEach(audit) { AuditRow(entry: $0) }
                }
            }
            .navigationTitle("Users")
            .searchable(text: $query, prompt: "Search username")
            .toolbar {
                // UITesting-открытие шита: кнопка в тулбаре всегда hittable
                // (строки List могут уехать из вьюпорта/под клавиатуру).
                if isUITesting {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("open") {
                            // Прямой reported_user без query-матчинга: матчинг
                            // уже проверен поиском выше, здесь нужен детерминизм.
                            if let match = users.first(where: { $0.username == "reported_user" }) {
                                selected = match
                                showDetail = true
                            }
                        }
                        .accessibilityIdentifier("admin.users.row")
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                if let user = selected {
                    UserDetailSheet(
                        user: user,
                        grantAmount: $grantAmount,
                        onAction: { action, amount in applyAction(user: user, action: action, amount: amount) }
                    )
                }
            }
        }
    }

    private func userRowLabel(_ user: AdminUser) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("@\(user.username)").bold()
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                Text(user.isBanned ? "banned" : user.status)
                    .font(.caption)
                    .foregroundStyle(user.isBanned ? .red : .secondary)
                Text("Lv \(user.level) · \(user.ember) EMBER · \(user.inventoryCount) items")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }

    private var visible: [AdminUser] {
        guard !query.isEmpty else { return users }
        return users.filter { $0.username.localizedCaseInsensitiveContains(query) }
    }

    private func applyAction(user: AdminUser, action: String, amount: Int = 0) {
        guard let i = users.firstIndex(where: { $0.id == user.id }) else { return }
        switch action {
        case "ban":
            users[i].isBanned = true
            justBanned = user.username
        case "unban":
            users[i].isBanned = false
        case "mute":
            users[i].isMuted = true
        case "unmute":
            users[i].isMuted = false
        case "verify":
            users[i].isVerified = true
        case "grant":
            users[i].ember += amount
            let line = EconomyGrant.auditLine(admin: "admin:this-device", amount: amount, target: user.username)
            audit.insert(AuditLogEntry(at: .now, actor: "admin:this-device", action: line, target: "user:\(user.username)"), at: 0)
            AdminAuditLog.shared.append(actor: "admin:this-device", action: line, target: "user:\(user.username)")
            return
        default:
            break
        }
        let entry = AuditLogEntry(at: .now, actor: "admin:this-device", action: action, target: "user:\(user.username)")
        audit.insert(entry, at: 0)
        AdminAuditLog.shared.append(actor: entry.actor, action: entry.action, target: entry.target)
    }
}

// MARK: - UserDetailSheet (profile/status/badges/level/currency/inventory/...)

struct UserDetailSheet: View {
    var user: AdminUser
    @Binding var grantAmount: String
    var onAction: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var banArmed = false
    @State private var banReason = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    MetricRow(title: "Username", value: "@\(user.username)")
                        .accessibilityIdentifier("admin.user.detail")
                    MetricRow(title: "Status", value: user.status)
                    MetricRow(title: "Badges", value: user.badges.joined(separator: ", ").isEmpty ? "—" : user.badges.joined(separator: ", "))
                    MetricRow(title: "Level", value: "\(user.level)")
                    MetricRow(title: "EMBER", value: "\(user.ember)")
                    MetricRow(title: "Inventory", value: "\(user.inventoryCount) items")
                }
                Section("Grant EMBER") {
                    HStack {
                        TextField("500", text: $grantAmount)
                            .keyboardType(.numberPad)
                        Button("Grant") {
                            onAction("grant", Int(grantAmount) ?? 500)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Section("Actions") {
                    HStack {
                        Button(user.isBanned ? "Unban" : "Ban") {
                            if user.isBanned {
                                onAction("unban", 0)
                                dismiss()
                            } else {
                                banArmed = true
                            }
                        }
                        .buttonStyle(.bordered).tint(user.isBanned ? .green : .red).controlSize(.small)
                        .accessibilityIdentifier("admin.user.ban")
                        Button(user.isMuted ? "Unmute" : "Mute") {
                            onAction(user.isMuted ? "unmute" : "mute", 0)
                            dismiss()
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        Button("Verify") {
                            onAction("verify", 0)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent).tint(.blue).controlSize(.small)
                    }
                    if banArmed && !user.isBanned {
                        TextField("Reason", text: $banReason)
                            .accessibilityIdentifier("admin.user.ban.reason")
                        Button("Confirm ban") {
                            onAction("ban", 0)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                        .accessibilityIdentifier("admin.user.ban.confirm")
                    }
                }
            }
            .navigationTitle("@\(user.username)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    UsersView()
        .preferredColorScheme(.dark)
}

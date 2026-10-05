// Lumeo — Sources/Features/Settings/SettingsView.swift
// Настройки: Account / Privacy / Notifications(15) / Appearance / Security /
// Data / Language (RU/EN с перезагрузкой) / Subscription (без Annual/Lifetime/Trial).
// Export/Delete account (Privacy by design). Без хардкода строк, haptics точечно, A11y.

import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru, en
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
}

// MARK: - Privacy enums

enum PrivacyLevel: String, CaseIterable, Identifiable {
    case hidden, friends, everyone
    var id: String { rawValue }
}

enum BirthdayVisibility: String, CaseIterable, Identifiable {
    case hidden, friends, dayMonth, full
    var id: String { rawValue }
}

// MARK: - NotificationKind (15 типов)

enum NotificationKind: String, CaseIterable, Identifiable {
    case session, accept, friend, message, squad, streak, achievement, level,
         gift, `case`, workshop, premium, security, birthday, update
    var id: String { rawValue }
    var localizationKey: String { "settings.notif.\(rawValue)" }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var language: AppLanguage = .ru
    @State private var email = "you@lumeo.app"
    @State private var username = "you"
    @State private var phone = "+7 900 000-00-00"
    @State private var birthdayVisibility: BirthdayVisibility = .friends
    @State private var onlinePrivacy: PrivacyLevel = .friends
    @State private var lastSeenPrivacy: LastSeenPrivacy = .recent
    @State private var profilePrivacy: PrivacyLevel = .friends
    @State private var requestsPrivacy: PrivacyLevel = .friends
    @State private var messagesPrivacy: PrivacyLevel = .friends
    @State private var birthdayPrivacy: PrivacyLevel = .friends
    @State private var gamesPrivacy: PrivacyLevel = .friends
    @State private var notifState: [NotificationKind: Bool] = Dictionary(
        uniqueKeysWithValues: NotificationKind.allCases.map { ($0, true) }
    )
    @State private var quietMode = false
    @State private var quietFrom = Date()
    @State private var quietTo = Date()
    @State private var favoritesOnly = false
    @State private var accent: Color = .orange
    @State private var oled = true
    @State private var animations = true
    @State private var reduceMotion = false
    @State private var hapticsEnabled = true
    @State private var faceIDEnabled = false
    @State private var devices = ["iPhone 17 · this device", "iPad · home"]
    @State private var twoFA = false
    @State private var keysRotatedAt: Date?
    @State private var cacheMB = 184.0
    @State private var storageUsedGB = 2.4
    @State private var mediaQuality = "auto"
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var restoredFlash = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                // MARK: Account
                Section(String(localized: "settings.account")) {
                    accountField(key: "settings.email", value: $email, keyboard: .emailAddress)
                    accountField(key: "settings.username", value: $username, keyboard: .default)
                    accountField(key: "settings.phone", value: $phone, keyboard: .phonePad)
                    Picker(String(localized: "settings.birthday"), selection: $birthdayVisibility) {
                        Text(String(localized: "settings.visibility.hidden")).tag(BirthdayVisibility.hidden)
                        Text(String(localized: "settings.visibility.friends")).tag(BirthdayVisibility.friends)
                        Text(String(localized: "settings.visibility.dayMonth")).tag(BirthdayVisibility.dayMonth)
                        Text(String(localized: "settings.visibility.full")).tag(BirthdayVisibility.full)
                    }
                    .frame(minHeight: 44)
                    NavigationLink(String(localized: "settings.profile")) { ProfileView() }
                        .frame(minHeight: 44)
                    NavigationLink(String(localized: "workshop.title")) { WorkshopView() }
                        .frame(minHeight: 44)
                }
                // MARK: Privacy (default Only friends)
                Section(String(localized: "settings.privacy")) {
                    privacyPicker(key: "settings.online", selection: $onlinePrivacy)
                    Picker(String(localized: "settings.lastSeen"), selection: $lastSeenPrivacy) {
                        Text(String(localized: "settings.lastSeen.exact")).tag(LastSeenPrivacy.exact)
                        Text(String(localized: "settings.lastSeen.recent")).tag(LastSeenPrivacy.recent)
                        Text(String(localized: "settings.lastSeen.hidden")).tag(LastSeenPrivacy.hidden)
                    }
                    .frame(minHeight: 44)
                    privacyPicker(key: "settings.profileVisibility", selection: $profilePrivacy)
                    privacyPicker(key: "settings.requests", selection: $requestsPrivacy)
                    privacyPicker(key: "settings.messages", selection: $messagesPrivacy)
                    privacyPicker(key: "settings.birthday", selection: $birthdayPrivacy)
                    privacyPicker(key: "settings.gamesVisibility", selection: $gamesPrivacy)
                }
                // MARK: Notifications (15 типов + quiet hours + избранные)
                Section(String(localized: "settings.notifications")) {
                    ForEach(NotificationKind.allCases) { kind in
                        Toggle(String(localized: "\(kind.localizationKey)"), isOn: Binding(
                            get: { notifState[kind] ?? true },
                            set: { notifState[kind] = $0 }
                        ))
                        .frame(minHeight: 44)
                    }
                    Toggle(String(localized: "settings.quietMode"), isOn: $quietMode)
                        .frame(minHeight: 44)
                    if quietMode {
                        DatePicker(String(localized: "settings.quiet.from"), selection: $quietFrom, displayedComponents: .hourAndMinute)
                        DatePicker(String(localized: "settings.quiet.to"), selection: $quietTo, displayedComponents: .hourAndMinute)
                    }
                    Toggle(String(localized: "settings.favoritesOnly"), isOn: $favoritesOnly)
                        .frame(minHeight: 44)
                }
                // MARK: Appearance
                Section(String(localized: "settings.appearance")) {
                    Picker(String(localized: "settings.theme"), selection: Binding(
                        get: { theme.current.name },
                        set: { theme.apply(named: $0) }
                    )) {
                        ForEach(AppTheme.all, id: \.name) { option in
                            Text(option.name).tag(option.name)
                        }
                    }
                    .frame(minHeight: 44)
                    ColorPicker(String(localized: "settings.accent"), selection: $accent)
                        .frame(minHeight: 44)
                    Toggle(String(localized: "settings.oled"), isOn: $oled)
                        .frame(minHeight: 44)
                    Toggle(String(localized: "settings.animations"), isOn: $animations)
                        .frame(minHeight: 44)
                    Toggle(String(localized: "settings.reduceMotion"), isOn: $reduceMotion)
                        .frame(minHeight: 44)
                    Toggle(String(localized: "settings.haptics"), isOn: $hapticsEnabled)
                        .frame(minHeight: 44)
                }
                // MARK: Security
                Section(String(localized: "settings.security")) {
                    Toggle(String(localized: "settings.faceID"), isOn: $faceIDEnabled)
                        .frame(minHeight: 44)
                        .onChange(of: faceIDEnabled) { _, enabled in
                            if enabled { enableFaceID() }
                        }
                    ForEach(devices, id: \.self) { device in
                        Label(device, systemImage: "iphone")
                            .frame(minHeight: 44)
                    }
                    Button(String(localized: "settings.logoutAll"), role: .destructive) {
                        devices = []
                    }
                    .frame(minHeight: 44)
                    Toggle(String(localized: "settings.twoFA"), isOn: $twoFA)
                        .frame(minHeight: 44)
                    HStack {
                        Text(String(localized: "settings.keys"))
                        Spacer()
                        if let at = keysRotatedAt {
                            Text(at.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(theme.current.textSecondary)
                        }
                        Button(String(localized: "settings.keys.rotate")) {
                            keysRotatedAt = .now // E2EE rotate stub
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(minHeight: 44)
                }
                // MARK: Data
                Section(String(localized: "settings.data")) {
                    Button(String(localized: "settings.export")) { exportJSON() }
                        .frame(minHeight: 44)
                    Button(String(localized: "settings.clearCache")) { cacheMB = 0 }
                        .frame(minHeight: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(String(localized: "settings.storage")): \(storageUsedGB, format: .number.precision(.fractionLength(1))) GB")
                            .font(.caption)
                        ProgressView(value: storageUsedGB / 8.0)
                            .tint(theme.current.primary)
                    }
                    Picker(String(localized: "settings.mediaQuality"), selection: $mediaQuality) {
                        Text(String(localized: "settings.media.auto")).tag("auto")
                        Text(String(localized: "settings.media.high")).tag("high")
                        Text(String(localized: "settings.media.dataSaver")).tag("dataSaver")
                    }
                    .frame(minHeight: 44)
                    Button(String(localized: "settings.offline.retry")) {
                        Task { await APIClient.shared.replayQueue() }
                    }
                    .tint(theme.current.primary)
                    .frame(minHeight: 44)
                }
                // MARK: Language (RU/EN с перезагрузкой)
                Section(String(localized: "settings.language")) {
                    Picker(String(localized: "settings.language"), selection: $language) {
                        Text("Русский").tag(AppLanguage.ru)
                        Text("English").tag(AppLanguage.en)
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                    .onChange(of: language) { _, new in
                        theme.locale = new.locale
                        // Перезагрузка UI: сброс кэша строк через смену locale.
                        NotificationCenter.default.post(name: .init("LumeoLocaleChanged"), object: new.rawValue)
                    }
                }
                // MARK: Subscription (Monthly/SixMonths + Group x3-5, restore stub)
                Section(String(localized: "settings.subscription")) {
                    PremiumRow(kind: .monthly)
                    PremiumRow(kind: .sixMonths)
                    PremiumRow(kind: .group)
                    Button(String(localized: "settings.premium.restore")) {
                        // StoreKit 2 restore stub (Фаза C — настоящий StoreKit).
                        restoredFlash = true
                    }
                    .frame(minHeight: 44)
                    if restoredFlash {
                        Label(String(localized: "settings.premium.restored"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(theme.current.success)
                    }
                }
                // MARK: Danger (Privacy by design)
                Section(String(localized: "settings.danger")) {
                    Button(String(localized: "settings.exportAccount")) { exportJSON() }
                        .frame(minHeight: 44)
                    Button(String(localized: "settings.deleteAccount"), role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .frame(minHeight: 44)
                    .confirmationDialog(
                        String(localized: "settings.delete.confirm"),
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "settings.deleteAccount"), role: .destructive) {}
                        Button(String(localized: "common.cancel"), role: .cancel) {}
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "settings.title"))
            .sheet(isPresented: $showExport) {
                if let exportURL {
                    ShareSheet(url: exportURL)
                }
            }
        }
        .tint(theme.current.primary)
    }

    private func accountField(key: String, value: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(String(localized: "\(key)"))
            Spacer()
            TextField(String(localized: "\(key)"), text: value)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.trailing)
                .frame(minHeight: 44)
        }
    }

    private func privacyPicker(key: String, selection: Binding<PrivacyLevel>) -> some View {
        Picker(String(localized: "\(key)"), selection: selection) {
            Text(String(localized: "settings.visibility.hidden")).tag(PrivacyLevel.hidden)
            Text(String(localized: "settings.visibility.friends")).tag(PrivacyLevel.friends)
            Text(String(localized: "settings.visibility.everyone")).tag(PrivacyLevel.everyone)
        }
        .frame(minHeight: 44)
    }

    private func exportJSON() {
        let payload: [String: String] = [
            "username": username, "email": email,
            "locale": language.rawValue, "exportedAt": ISO8601DateFormatter().string(from: .now),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted) {
            let url = FileManager.default.temporaryDirectory.appending(path: "lumeo-export.json")
            try? data.write(to: url)
            exportURL = url
            showExport = true
        }
    }

    private func enableFaceID() {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            faceIDEnabled = false
            return
        }
        // TODO(security): evaluatePolicy + флаг в Keychain; разблокировка AppLock.
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - PremiumRow

enum PremiumKind {
    case monthly, sixMonths, group
}

struct PremiumRow: View {
    @Environment(ThemeManager.self) private var theme
    var kind: PremiumKind

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(theme.current.text)
                Text(String(localized: "settings.premium.hint"))
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
            }
            Spacer()
            Button(String(localized: "settings.premium.buy")) {
                // TODO(storekit): StoreKit 2, Фаза C. Сейчас — заглушка без списаний.
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            .controlSize(.small)
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch kind {
        case .monthly: String(localized: "settings.premium.monthly")
        case .sixMonths: String(localized: "settings.premium.sixMonths")
        case .group: String(localized: "settings.premium.group")
        }
    }
}

#Preview {
    SettingsView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

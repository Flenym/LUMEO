// Lumeo — Sources/AppIntents/AppIntents.swift
// Все 10 интентов из ТЗ: SetGreen / SetYellow / SetRed, OpenFriends / OpenChats /
// OpenProfile, CreateSession, OpenActiveSession, JoinSession, LeaveSession.
// Siri phrases + Shortcuts donation (AppShortcutsProvider). Deep-link через App Group.

import AppIntents
import Foundation

// MARK: - DeepLinkStore

/// Общий ящик deep-link'ов (App Group group.com.lumeo.app). Main App проверяет при старте.
enum DeepLinkStore {
    private static let suite = "group.com.lumeo.app"
    private static let key = "pendingDeepLink"

    static func request(section: String) {
        UserDefaults(suiteName: suite)?.set(section, forKey: key)
    }

    static func consume() -> String? {
        let defaults = UserDefaults(suiteName: suite)
        let value = defaults?.string(forKey: key)
        defaults?.removeObject(forKey: key)
        return value
    }
}

// MARK: - Status intents (3)

struct SetGreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Set status: Free"
    static let description = IntentDescription("Поставить статус 🟢 Свободен.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "status.green")
        // TODO(sync): записать статус через APIClient + WidgetCenter.reloadAllTimelines().
        .result()
    }
}

struct SetYellowIntent: AppIntent {
    static let title: LocalizedStringResource = "Set status: Later"
    static let description = IntentDescription("Поставить статус 🟡 Буду позже.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "status.yellow")
        return .result()
    }
}

struct SetRedIntent: AppIntent {
    static let title: LocalizedStringResource = "Set status: Busy"
    static let description = IntentDescription("Поставить статус 🔴 Занят.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "status.red")
        return .result()
    }
}

// MARK: - Open section intents (3)

struct OpenFriendsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Friends"
    static let description = IntentDescription("Открыть раздел Друзья в Lumeo.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "friends")
        return .result()
    }
}

struct OpenChatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Chats"
    static let description = IntentDescription("Открыть раздел Чаты в Lumeo.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "chats")
        return .result()
    }
}

struct OpenProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Profile"
    static let description = IntentDescription("Открыть Профиль в Lumeo.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "profile")
        return .result()
    }
}

// MARK: - Session intents (4)

struct CreateSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Session"
    static let description = IntentDescription("Создать Session «Поиграем?» в Lumeo.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "session.create")
        return .result()
    }
}

struct OpenActiveSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Active Session"
    static let description = IntentDescription("Открыть активную Session.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "session.active")
        return .result()
    }
}

struct JoinSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Join Session"
    static let description = IntentDescription("Войти в активную Session.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "session.join")
        // TODO(backend): POST /api/v1/sessions/active/join.
        return .result()
    }
}

struct LeaveSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Leave Session"
    static let description = IntentDescription("Выйти из активной Session.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkStore.request(section: "session.leave")
        // TODO(backend): POST /api/v1/sessions/active/leave.
        return .result()
    }
}

// MARK: - Shortcuts provider (все 10 + Siri phrases, Shortcuts donation)

/// Набор для App Shortcuts (Siri / Shortcuts): все 10 интентов с фразами.
struct LumeoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetGreenIntent(),
            phrases: [
                "Set Lumeo status to free",
                "Поставь статус свободен в Люмео",
            ],
            shortTitle: "I'm free",
            systemImageName: "circle.fill"
        )
        AppShortcut(
            intent: SetYellowIntent(),
            phrases: ["Set Lumeo status to later", "Поставь статус буду позже в Люмео"],
            shortTitle: "Be later",
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: SetRedIntent(),
            phrases: ["Set Lumeo status to busy", "Поставь статус занят в Люмео"],
            shortTitle: "I'm busy",
            systemImageName: "nosign"
        )
        AppShortcut(
            intent: OpenFriendsIntent(),
            phrases: ["Open Lumeo friends", "Открой друзей в Люмео"],
            shortTitle: "Friends",
            systemImageName: "person.2.fill"
        )
        AppShortcut(
            intent: OpenChatsIntent(),
            phrases: ["Open Lumeo chats", "Открой чаты в Люмео"],
            shortTitle: "Chats",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
        AppShortcut(
            intent: OpenProfileIntent(),
            phrases: ["Open my Lumeo profile", "Открой мой профиль в Люмео"],
            shortTitle: "Profile",
            systemImageName: "person.crop.circle.fill"
        )
        AppShortcut(
            intent: CreateSessionIntent(),
            phrases: ["Create Lumeo session", "Создай игру в Люмео"],
            shortTitle: "Let's play",
            systemImageName: "gamecontroller.fill"
        )
        AppShortcut(
            intent: OpenActiveSessionIntent(),
            phrases: ["Open active Lumeo session", "Открой активную игру в Люмео"],
            shortTitle: "Active session",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: JoinSessionIntent(),
            phrases: ["Join Lumeo session", "Войди в игру в Люмео"],
            shortTitle: "Join",
            systemImageName: "arrow.right.circle.fill"
        )
        AppShortcut(
            intent: LeaveSessionIntent(),
            phrases: ["Leave Lumeo session", "Выйди из игры в Люмео"],
            shortTitle: "Leave",
            systemImageName: "arrow.left.circle.fill"
        )
    }
}

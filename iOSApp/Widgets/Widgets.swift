// Lumeo — Widgets/Widgets.swift
// Tier5: 4 виджета (WidgetKit Timeline):
// 1) Small «Кто свободен» 2) Medium «Друзья» 3) Medium «Мой Squad» (intent-configuration
//    выбор squad) 4) Status с кнопками 🟢🟡🔴 (работают через AppIntent).
// Deep-link tap: widgetURL → Main App открывает раздел.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Entry

struct FriendsEntry: TimelineEntry {
    var date: Date
    var freeCount: Int
    var playingCount: Int
    var squadName: String
    var streakDays: Int
}

// MARK: - Squad chooser (intent-configuration)

/// Выбор squad для виджета «Мой Squad» (intent-configuration).
struct SquadSelectionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose squad"
    static let description = IntentDescription("Выбрать сквад для виджета.")

    @Parameter(title: "Squad")
    var squadName: String?

    init() {}
    init(squadName: String) {
        self.squadName = squadName
    }
}

struct SquadEntry: TimelineEntry {
    var date: Date
    var squadName: String
    var streakDays: Int
}

struct SquadProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SquadEntry {
        SquadEntry(date: .now, squadName: "Night Owls", streakDays: 12)
    }

    func snapshot(for configuration: SquadSelectionIntent, in context: Context) async -> SquadEntry {
        SquadEntry(date: .now, squadName: configuration.squadName ?? "Night Owls", streakDays: 12)
    }

    func timeline(for configuration: SquadSelectionIntent, in context: Context) async -> Timeline<SquadEntry> {
        // TODO(sync): читать снапшот из App Group (group.com.lumeo.app), обновлять по push.
        let entry = SquadEntry(date: .now, squadName: configuration.squadName ?? "Night Owls", streakDays: 12)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Provider (static)

struct FriendsProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendsEntry {
        FriendsEntry(date: .now, freeCount: 3, playingCount: 1, squadName: "Night Owls", streakDays: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendsEntry>) -> Void) {
        // TODO(sync): читать снапшот из App Group (group.com.lumeo.app), обновлять по push.
        let entry = FriendsEntry(date: .now, freeCount: 3, playingCount: 1, squadName: "Night Owls", streakDays: 12)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget intents (кнопки статуса — работают через AppIntent)

struct WidgetSetGreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Set status: Free"
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkWidgetStore.request(section: "status.green")
        return .result()
    }
}

struct WidgetSetYellowIntent: AppIntent {
    static let title: LocalizedStringResource = "Set status: Later"
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkWidgetStore.request(section: "status.yellow")
        return .result()
    }
}

struct WidgetSetRedIntent: AppIntent {
    static let title: LocalizedStringResource = "Set status: Busy"
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        DeepLinkWidgetStore.request(section: "status.red")
        return .result()
    }
}

/// Локальный DeepLinkStore виджета (App Group group.com.lumeo.app).
enum DeepLinkWidgetStore {
    static func request(section: String) {
        UserDefaults(suiteName: "group.com.lumeo.app")?.set(section, forKey: "pendingDeepLink")
    }
}

// MARK: - 1) Small «Кто свободен» (deep-link tap → friends)

struct WhosFreeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.lumeo.widget.whosfree", provider: FriendsProvider()) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text("🟢 \(entry.freeCount)")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Free now")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .containerBackground(.black, for: .widget)
            .widgetURL(URL(string: "lumeo://friends"))
        }
        .configurationDisplayName("Who's Free")
        .description("Сколько друзей свободно прямо сейчас.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 2) Medium «Друзья» (deep-link tap → friends)

struct FriendsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.lumeo.widget.friends", provider: FriendsProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text("Friends")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 16) {
                    Label("\(entry.freeCount) free", systemImage: "circle.fill")
                    Label("\(entry.playingCount) playing", systemImage: "gamecontroller.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .containerBackground(.black, for: .widget)
            .widgetURL(URL(string: "lumeo://friends"))
        }
        .configurationDisplayName("Friends")
        .description("Свободны и играют сейчас.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 3) Medium «Мой Squad» (intent-configuration: выбор squad, deep-link tap)

struct SquadWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "com.lumeo.widget.squad",
            intent: SquadSelectionIntent.self,
            provider: SquadProvider()
        ) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.squadName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Label("\(entry.streakDays)-day streak", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .containerBackground(.black, for: .widget)
            .widgetURL(URL(string: "lumeo://squads?name=\(entry.squadName)"))
        }
        .configurationDisplayName("My Squad")
        .description("Streak твоего сквада. Squad выбирается в настройках виджета.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 4) Status с кнопками (работают через AppIntent)

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.lumeo.widget.status", provider: FriendsProvider()) { _ in
            HStack(spacing: 12) {
                Button(intent: WidgetSetGreenIntent()) {
                    Text("🟢").font(.title)
                }
                Button(intent: WidgetSetYellowIntent()) {
                    Text("🟡").font(.title)
                }
                Button(intent: WidgetSetRedIntent()) {
                    Text("🔴").font(.title)
                }
            }
            .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Status")
        .description("Переключить статус одной кнопкой.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct LumeoWidgets: WidgetBundle {
    var body: some Widget {
        WhosFreeWidget()
        FriendsWidget()
        SquadWidget()
        StatusWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    WhosFreeWidget()
} timeline: {
    FriendsEntry(date: .now, freeCount: 3, playingCount: 1, squadName: "Night Owls", streakDays: 12)
}

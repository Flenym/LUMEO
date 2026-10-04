// Lumeo — LiveActivities/LiveSessionActivity.swift
// Live Activity активной Session + Dynamic Island (compact/expanded) + Lock Screen.
// Старт / апдейт / конец — из SessionBanner через LiveSessionStarter.

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes

struct LiveSessionAttributes: ActivityAttributes {
    /// Static: не меняется за время активности.
    var game: String
    var slotsTotal: Int

    /// Dynamic: обновляется push/WS (слоты, состояние, конец).
    struct ContentState: Codable, Hashable {
        var slotsTaken: Int
        var state: String
        var endsAt: Date?
    }
}

// MARK: - LiveSessionActivity

struct LiveSessionActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveSessionAttributes.self) { context in
            // Lock Screen / StandBy.
            HStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.game)
                        .font(.headline)
                    Text("\(context.state.slotsTaken)/\(context.attributes.slotsTotal) · \(context.state.state)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let endsAt = context.state.endsAt, endsAt > Date() {
                    Text(timerInterval: Date()...endsAt, countsDown: true)
                        .font(.headline.monospacedDigit())
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.game).font(.headline)
                        Text(context.state.state).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.slotsTaken)/\(context.attributes.slotsTotal)")
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ProgressView(value: Double(context.state.slotsTaken) / Double(max(context.attributes.slotsTotal, 1)))
                            .tint(.orange)
                        if let endsAt = context.state.endsAt, endsAt > Date() {
                            Text(timerInterval: Date()...endsAt, countsDown: true)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text("\(context.state.slotsTaken)/\(context.attributes.slotsTotal)")
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "gamecontroller.fill")
            }
        }
    }
}

// MARK: - LiveSessionStarter (старт / апдейт / конец)

/// Хелпер старта/обновления/завершения из Main App (вызывать при Live/Paused/Finished).
enum LiveSessionStarter {
    /// Старт Live Session.
    static func start(session: GameSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endStale()
        let attributes = LiveSessionAttributes(game: session.game, slotsTotal: session.slotsTotal)
        let state = LiveSessionAttributes.ContentState(
            slotsTaken: session.slotsTaken, state: session.state.rawValue, endsAt: session.startsAt
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            // Live Activity недоступна (лимит системы / запрет) — молча пропускаем.
        }
    }

    /// Апдейт: слоты / состояние / таймер (вызывать на каждое изменение Session).
    /// Типы указаны явно: `.init`-сокращения без контекста ломают инференс (Xcode 26).
    static func update(slotsTaken: Int, state: String, endsAt: Date? = nil) async {
        for activity in Activity<LiveSessionAttributes>.activities {
            let contentState = LiveSessionAttributes.ContentState(
                slotsTaken: slotsTaken, state: state, endsAt: endsAt
            )
            let content = ActivityContent(state: contentState, staleDate: nil)
            await activity.update(content)
        }
    }

    /// Конец: штатное завершение (Finished/Cancelled) — с финальным состоянием.
    static func end(state: String = "finished") async {
        for activity in Activity<LiveSessionAttributes>.activities {
            let contentState = LiveSessionAttributes.ContentState(
                slotsTaken: 0, state: state, endsAt: nil
            )
            let final = ActivityContent(state: contentState, staleDate: nil)
            await activity.end(final, dismissalPolicy: .immediate)
        }
    }

    /// Совместимость: мгновенно завершить все.
    static func endAll() async {
        await end(state: "finished")
    }

    private static func endStale() {
        // Не более одной активной Live Session: старые гасим fire-and-forget.
        guard !Activity<LiveSessionAttributes>.activities.isEmpty else { return }
        Task { await end(state: "replaced") }
    }
}

// Lumeo Admin — Sources/Core/AdminModels.swift
// Общие модели Admin App.
//
// ПРИВАТНОСТЬ (строго): E2EE-plaintext сообщений НЕ показывать НИГДЕ.
// Модерация работает только с metadata: message_id, sender_hash, timestamps,
// attachment kind/size, report_cluster_id. Тексты жалоб пользователей — можно (это репорты, не чаты).

import Foundation

// MARK: - AuditLogEntry

/// Единая строка audit log: кто / что / когда. Пишется на каждый admin-action.
struct AuditLogEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var at: Date
    var actor: String
    var action: String
    var target: String
}

// MARK: - AdminMessageMetadata

/// Metadata сообщения для модерации БЕЗ plaintext (E2EE: сервер его не знает).
struct AdminMessageMetadata: Identifiable, Hashable {
    var id: UUID
    var senderHash: String
    var chatID: UUID
    var createdAt: Date
    var attachmentKind: String?
    var attachmentSizeBytes: Int?
    var reportCount: Int
}

// MARK: - ReportItem

/// Жалоба пользователя. Дедупликация по report_cluster_id (см. ReportCluster).
struct ReportItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var clusterID: String
    var reason: String
    var reporterHash: String
    var targetHash: String
    var createdAt: Date = .now
    var status: ReportStatus = .open
}

enum ReportStatus: String, Hashable {
    case open, inReview, actioned, dismissed
}

// MARK: - ReportCluster

/// Дедупликация репортов: одинаковые (target + reason) схлопываются в кластер.
enum ReportCluster {
    static func clusterID(targetHash: String, reason: String) -> String {
        let normReason = reason.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(targetHash)#\(normReason)"
    }

    static func grouped(_ reports: [ReportItem]) -> [(clusterID: String, items: [ReportItem])] {
        let dict = Dictionary(grouping: reports, by: { $0.clusterID })
        return dict.map { (clusterID: $0.key, items: $0.value) }
            .sorted { $0.items.count > $1.items.count }
    }
}

// MARK: - VerificationRequest

/// Заявка на бейдж Verified — решается ТОЛЬКО через Admin (VerificationView).
/// 5 типов очередей: identity / streamer / tournament / developer / sponsor.
enum VerificationKind: String, Hashable, CaseIterable {
    case identity, streamer, tournament, developer, sponsor
}

enum VerificationDecision: String, Hashable {
    case pending, approved, rejected
}

struct VerificationRequest: Identifiable, Hashable {
    var id: UUID = UUID()
    var username: String
    var kind: VerificationKind
    var reason: String
    var createdAt: Date = .now
    var decision: VerificationDecision = .pending

    init(id: UUID = UUID(), username: String, reason: String, createdAt: Date = .now) {
        self.id = id
        self.username = username
        self.kind = .identity
        self.reason = reason
        self.createdAt = createdAt
    }

    init(id: UUID = UUID(), username: String, kind: VerificationKind, reason: String, createdAt: Date = .now) {
        self.id = id
        self.username = username
        self.kind = kind
        self.reason = reason
        self.createdAt = createdAt
    }
}

// MARK: - BetaGate (Beta закрыта флагом)

/// Beta-бейдж закрыт: approve запрещён, только история.
enum BetaGate {
    static var isBetaClosed = true

    static func canApprove(kind: VerificationKind) -> Bool {
        // Beta-очередь закрыта отдельным флагом (см. VerificationView).
        true
    }
}

// MARK: - EconomyGrant (grant/revoke + audit line)

/// Grant/revoke EMBER: каждая операция пишет audit-строку формата
/// «Admin granted 500 EMBER to @x».
enum EconomyGrant {
    static func auditLine(admin: String, amount: Int, target: String, currency: String = "EMBER") -> String {
        let verb = amount >= 0 ? "granted" : "revoked"
        return "Admin \(verb) \(abs(amount)) \(currency) to @\(target) (by \(admin))"
    }

    /// Каноническая строка из ТЗ для логов/тестов.
    static var canonicalExample: String {
        "Admin granted 500 EMBER to @x"
    }

    static func entry(admin: String, target: String, amount: Int, reason: String) -> AuditLogEntry {
        AuditLogEntry(at: .now, actor: admin, action: "grant:\(amount):\(reason)", target: "user:\(target)")
    }
}

// MARK: - ServerMetrics

struct ServerMetrics: Hashable {
    var cpuPercent: Double
    var ramPercent: Double
    var storagePercent: Double
    var dbLatencyMs: Int
    var wsConnections: Int
    var errorsPerMin: Int
    var uptimeHours: Double
    var cloudPubOnline: Bool

    static var demo: ServerMetrics {
        ServerMetrics(cpuPercent: 34, ramPercent: 58, storagePercent: 41,
                      dbLatencyMs: 12, wsConnections: 1840, errorsPerMin: 2,
                      uptimeHours: 312, cloudPubOnline: true)
    }
}

// MARK: - AnalyticsSeries

struct AnalyticsSeries: Hashable {
    var label: String
    var values: [Double]
}

// MARK: - ContentItem (games/themes/rewards/badges/achievements CRUD)

enum ContentKind: String, Hashable, CaseIterable {
    case games, themes, rewards, badges, achievements
}

struct ContentItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: ContentKind
    var title: String
    var detail: String
}

// MARK: - Preview data

enum AdminPreviewData {
    static let audit: [AuditLogEntry] = [
        AuditLogEntry(at: .now.addingTimeInterval(-300), actor: "owner", action: "ban_user", target: "user:dex"),
        AuditLogEntry(at: .now.addingTimeInterval(-900), actor: "admin:mira", action: "approve_theme", target: "theme:neon-grid"),
        AuditLogEntry(at: .now.addingTimeInterval(-1800), actor: "owner", action: "verify_user", target: "user:neo"),
    ]

    static let reports: [ReportItem] = {
        let cluster = ReportCluster.clusterID(targetHash: "user:spam1", reason: "Spam invites")
        return [
            ReportItem(clusterID: cluster, reason: "Spam invites", reporterHash: "user:a", targetHash: "user:spam1"),
            ReportItem(clusterID: cluster, reason: "Spam invites", reporterHash: "user:b", targetHash: "user:spam1"),
            ReportItem(clusterID: ReportCluster.clusterID(targetHash: "user:tox9", reason: "Toxic status"), reason: "Toxic status", reporterHash: "user:c", targetHash: "user:tox9"),
        ]
    }()

    static let verifications: [VerificationRequest] = [
        VerificationRequest(username: "neo", kind: .tournament, reason: "Tournament organizer"),
        VerificationRequest(username: "mira_fps", kind: .streamer, reason: "Streamer, 50k followers"),
        VerificationRequest(username: "dex", kind: .identity, reason: "Passport check"),
        VerificationRequest(username: "kate_dev", kind: .developer, reason: "Shipped 3 integrations"),
        VerificationRequest(username: "leo", kind: .sponsor, reason: "Season sponsor"),
    ]

    static let content: [ContentItem] = [
        ContentItem(kind: .games, title: "Valorant", detail: "5x5 · active"),
        ContentItem(kind: .themes, title: "OLED Orange", detail: "official · v2.0"),
        ContentItem(kind: .rewards, title: "Neon Frame", detail: "199 EMBER"),
        ContentItem(kind: .badges, title: "Verified", detail: "blue check"),
        ContentItem(kind: .achievements, title: "First Session", detail: "common"),
    ]

    static let dau = AnalyticsSeries(label: "DAU", values: [8.1, 9.4, 9.0, 10.2, 11.1, 12.4, 11.8])
    static let wau = AnalyticsSeries(label: "WAU", values: [31, 33, 32, 35, 38, 41, 40])
    static let acceptRate = AnalyticsSeries(label: "Accept %", values: [62, 65, 64, 68, 71, 73, 72])

    /// Каноническая audit-строка гранта (показывается во всех табах).
    static let grantExample = EconomyGrant.canonicalExample
}
}

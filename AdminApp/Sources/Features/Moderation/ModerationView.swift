// Lumeo Admin — Sources/Features/Moderation/ModerationView.swift
// Модерация: очередь репортов с дедупликацией по report_cluster_id (count),
// approve/reject, workshop queue, restrict. Audit log.
// СТРОГО: только metadata (message_id, sender_hash, timestamps, kind/size).
// E2EE-plaintext НЕ показывается — сервер его не знает и знать не должен.

import SwiftUI

// MARK: - ModerationView

struct ModerationView: View {
    @State private var reports: [ReportItem] = AdminPreviewData.reports
    @State private var workshopPending = 2
    @State private var audit: [AuditLogEntry] = AdminPreviewData.audit

    var body: some View {
        NavigationStack {
            List {
                Section("Queue (grouped by report_cluster_id)") {
                    ForEach(clustered, id: \.clusterID) { cluster in
                        ClusterRow(
                            clusterID: cluster.clusterID,
                            items: cluster.items,
                            onAction: { action(cluster, action: $0) }
                        )
                    }
                }
                Section("Workshop queue") {
                    MetricRow(title: "Pending themes", value: "\(workshopPending)")
                    HStack {
                        Button("Approve") {
                            workshopPending = max(0, workshopPending - 1)
                            log(action: "approve_theme", target: "theme:queue")
                        }
                        .buttonStyle(.borderedProminent).tint(.green).controlSize(.small)
                        Button("Reject") {
                            workshopPending = max(0, workshopPending - 1)
                            log(action: "reject_theme", target: "theme:queue")
                        }
                        .buttonStyle(.bordered).tint(.red).controlSize(.small)
                    }
                }
                Section("Message metadata (no plaintext)") {
                    // Только metadata: id/from/to/time/status — без текстов.
                    ForEach(demoMetadata) { meta in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meta.id.uuidString.prefix(8))
                                .font(.caption.monospacedDigit().bold())
                            Text("\(meta.senderHash) → \(meta.chatID.uuidString.prefix(8)) · \(meta.createdAt, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("kind: \(meta.attachmentKind ?? "text") · reports: ×\(meta.reportCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                Section("Audit") {
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    ForEach(audit) { AuditRow(entry: $0) }
                }
            }
            .navigationTitle("Moderation")
        }
    }

    private var demoMetadata: [AdminMessageMetadata] {
        [
            AdminMessageMetadata(id: UUID(), senderHash: "user:spam1",
                                 chatID: UUID(), createdAt: .now.addingTimeInterval(-600),
                                 attachmentKind: "text", attachmentSizeBytes: 48, reportCount: 3),
            AdminMessageMetadata(id: UUID(), senderHash: "user:tox9",
                                 chatID: UUID(), createdAt: .now.addingTimeInterval(-1200),
                                 attachmentKind: "photo", attachmentSizeBytes: 240_000, reportCount: 1),
        ]
    }

    private var clustered: [(clusterID: String, items: [ReportItem])] {
        ReportCluster.grouped(reports.filter { $0.status == .open || $0.status == .inReview })
    }

    private func action(_ cluster: (clusterID: String, items: [ReportItem]), action: String) {
        for item in cluster.items {
            guard let i = reports.firstIndex(where: { $0.id == item.id }) else { continue }
            reports[i].status = action == "dismiss" || action == "reject" ? .dismissed : .actioned
        }
        log(action: "moderate:\(action)", target: "cluster:\(cluster.clusterID)")
        // TODO(backend): POST /api/v1/admin/moderation/clusters/{id}/{action}.
    }

    private func restrict(target: String) {
        log(action: "restrict_user", target: target)
        // TODO(backend): POST /api/v1/admin/users/{id}/restrict.
    }

    private func log(action: String, target: String) {
        audit.insert(
            AuditLogEntry(at: .now, actor: "admin:this-device", action: action, target: target),
            at: 0
        )
    }
}

// MARK: - ClusterRow (count badge + approve/reject + restrict)

struct ClusterRow: View {
    var clusterID: String
    var items: [ReportItem]
    var onAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(items.first?.reason ?? "")
                    .font(.subheadline.bold())
                Spacer()
                Text("×\(items.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2), in: .capsule)
                    .accessibilityLabel("\(items.count) reports")
            }
            Text("cluster: \(clusterID)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("target: \(items.first?.targetHash ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Approve") { onAction("approve") }.buttonStyle(.borderedProminent).tint(.green).controlSize(.small)
                Button("Reject") { onAction("reject") }.buttonStyle(.bordered).tint(.red).controlSize(.small)
                Button("Hide") { onAction("hide") }.buttonStyle(.bordered).controlSize(.small)
                Button("Restrict") { onAction("restrict") }.buttonStyle(.bordered).tint(.orange).controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModerationView()
        .preferredColorScheme(.dark)
}

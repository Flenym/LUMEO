// Lumeo Admin — Sources/Features/Verification/VerificationView.swift
// Верификация (синяя галка): заявки approve/reject ТОЛЬКО через Admin.
// 5 типов очередей (identity/streamer/tournament/developer/sponsor) + история.
// Beta закрыта флагом (BetaGate.isBetaClosed): новых Beta-заявок нет, только история.
// Клиент не может выдать себе бейдж — флаг ставит backend по admin-action.

import SwiftUI

// MARK: - VerificationView

struct VerificationView: View {
    @State private var requests: [VerificationRequest] = AdminPreviewData.verifications
    @State private var history: [AuditLogEntry] = []
    @State private var audit: [AuditLogEntry] = AdminPreviewData.audit
    @State private var selectedKind: VerificationKind? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Beta") {
                    // Beta закрыта флагом.
                    Label(
                        BetaGate.isBetaClosed ? "Beta is closed" : "Beta is open",
                        systemImage: BetaGate.isBetaClosed ? "lock.fill" : "lock.open.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(BetaGate.isBetaClosed ? .orange : .green)
                }
                Section("Queues (5 types)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            kindChip(title: "All", kind: nil)
                            ForEach(VerificationKind.allCases, id: \.self) { kind in
                                kindChip(title: kind.rawValue, kind: kind)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
                Section("Pending") {
                    if filtered.isEmpty {
                        Text("Queue is empty").foregroundStyle(.secondary)
                    }
                    ForEach(filtered) { request in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("@\(request.username)").font(.headline)
                                Spacer()
                                Text(request.kind.rawValue)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.blue.opacity(0.2), in: .capsule)
                            }
                            Text(request.reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Approve") { decide(request, approved: true) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .controlSize(.small)
                                Button("Reject") { decide(request, approved: false) }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("History") {
                    if history.isEmpty {
                        Text("No decisions yet").foregroundStyle(.secondary)
                    }
                    ForEach(history) { AuditRow(entry: $0) }
                }
                Section("Audit") {
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    ForEach(audit) { AuditRow(entry: $0) }
                }
            }
            .navigationTitle("Verification")
        }
    }

    private var filtered: [VerificationRequest] {
        guard let selectedKind else { return requests.filter { $0.decision == .pending } }
        return requests.filter { $0.decision == .pending && $0.kind == selectedKind }
    }

    private func kindChip(title: String, kind: VerificationKind?) -> some View {
        Button(title) { selectedKind = kind }
            .buttonStyle(.bordered)
            .tint(selectedKind == kind ? .blue : nil)
            .controlSize(.small)
    }

    private func decide(_ request: VerificationRequest, approved: Bool) {
        requests.removeAll { $0.id == request.id }
        let entry = AuditLogEntry(at: .now, actor: "admin:this-device",
                                  action: approved ? "verify_user" : "reject_verification",
                                  target: "user:\(request.username):\(request.kind.rawValue)")
        history.insert(entry, at: 0)
        audit.insert(entry, at: 0)
        // TODO(backend): POST /api/v1/admin/verification/{id}/{approve|reject}.
    }
}

#Preview {
    VerificationView()
        .preferredColorScheme(.dark)
}

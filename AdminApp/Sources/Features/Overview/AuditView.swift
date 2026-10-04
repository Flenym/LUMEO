// Lumeo Admin — Sources/Features/Overview/AuditView.swift
// Audit-таб: общий лог действий администратора (AdminAuditLog.shared).
// Ban-записи получают идентификатор admin.audit.banEntry (AdminUITests).

import SwiftUI

// MARK: - AuditView

struct AuditView: View {
    @State private var log = AdminAuditLog.shared

    var body: some View {
        NavigationStack {
            List(log.entries) { entry in
                AuditRow(entry: entry)
                    .accessibilityIdentifier(entry.action == "ban" ? "admin.audit.banEntry" : "admin.audit.entry")
            }
            .navigationTitle("Audit")
        }
        .task {
            log.seedIfEmpty()
        }
    }
}

#Preview {
    AuditView()
        .preferredColorScheme(.dark)
}

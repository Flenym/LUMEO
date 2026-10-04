// Lumeo Admin — Sources/Features/Content/ContentView.swift
// Контент CRUD: games / themes / rewards / badges / achievements +
// модерация Workshop-тем (Pending → Published / Rejected),
// правило «мин. 5 бесплатных перед первой платной», официальные темы.

import SwiftUI

// MARK: - WorkshopReviewItem

struct WorkshopReviewItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var author: String
    var freeCountByAuthor: Int
    var isFree: Bool
    var status: String = "pending"
}

// MARK: - ContentView

struct ContentView: View {
    @State private var queue: [WorkshopReviewItem] = [
        WorkshopReviewItem(name: "Neon Grid", author: "mira", freeCountByAuthor: 6, isFree: true),
        WorkshopReviewItem(name: "Sunset Duo", author: "mira", freeCountByAuthor: 6, isFree: false),
        WorkshopReviewItem(name: "First Paid", author: "newbie", freeCountByAuthor: 2, isFree: false),
    ]
    @State private var items: [ContentItem] = AdminPreviewData.content
    @State private var newTitle = ""
    @State private var selectedKind: ContentKind = .games
    @State private var audit: [AuditLogEntry] = AdminPreviewData.audit

    var body: some View {
        NavigationStack {
            List {
                Section("CRUD: games / themes / rewards / badges / achievements") {
                    Picker("Kind", selection: $selectedKind) {
                        ForEach(ContentKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    HStack {
                        TextField("New title", text: $newTitle)
                        Button("Add") {
                            guard !newTitle.isEmpty else { return }
                            items.append(ContentItem(kind: selectedKind, title: newTitle, detail: "draft"))
                            audit.insert(
                                AuditLogEntry(at: .now, actor: "admin:this-device",
                                              action: "content_create:\(selectedKind.rawValue)",
                                              target: "content:\(newTitle)"),
                                at: 0
                            )
                            newTitle = ""
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                    ForEach(items.filter { $0.kind == selectedKind }) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title).bold()
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Delete", role: .destructive) {
                                items.removeAll { $0.id == item.id }
                                audit.insert(
                                    AuditLogEntry(at: .now, actor: "admin:this-device",
                                                  action: "content_delete", target: "content:\(item.title)"),
                                    at: 0
                                )
                            }
                            .buttonStyle(.bordered).tint(.red).controlSize(.small)
                        }
                    }
                }
                Section("Pending moderation") {
                    ForEach(queue.filter { $0.status == "pending" }) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name).font(.headline)
                            Text("by \(item.author) · free by author: \(item.freeCountByAuthor)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !item.isFree && item.freeCountByAuthor < 5 {
                                // Правило публикации: минимум 5 бесплатных перед платными.
                                Label("Blocked: needs 5 free first", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            HStack {
                                Button("Publish") { decide(item, approved: true) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .controlSize(.small)
                                    .disabled(!item.isFree && item.freeCountByAuthor < 5)
                                Button("Reject") { decide(item, approved: false) }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Audit") {
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    ForEach(audit) { AuditRow(entry: $0) }
                }
            }
            .navigationTitle("Content")
        }
    }

    private func decide(_ item: WorkshopReviewItem, approved: Bool) {
        guard let i = queue.firstIndex(where: { $0.id == item.id }) else { return }
        queue[i].status = approved ? "published" : "rejected"
        audit.insert(
            AuditLogEntry(at: .now, actor: "admin:this-device",
                          action: approved ? "approve_theme" : "reject_theme",
                          target: "theme:\(item.name.lowercased().replacingOccurrences(of: " ", with: "-"))"),
            at: 0
        )
        // TODO(backend): POST /api/v1/admin/workshop/{id}/{publish|reject}.
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

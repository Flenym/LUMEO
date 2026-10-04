// Lumeo Admin — Sources/Features/Overview/OverviewView.swift
// Обзор: stat cards users/online/sessions/messages/reports/new/beta/server + audit log.

import SwiftUI

// MARK: - OverviewView

struct OverviewView: View {
    private let metrics: [(title: String, value: String, icon: String)] = [
        ("Users", "48 210", "person.2.fill"),
        ("Online", "6 431", "circle.fill"),
        ("Sessions today", "3 912", "gamecontroller.fill"),
        ("Messages today", "182K", "bubble.left.and.bubble.right.fill"),
        ("Reports open", "\(AdminPreviewData.reports.count)", "flag.fill"),
        ("New today", "312", "sparkles"),
        ("Beta queue", "closed", "testtube.2"),
        ("Server", "ok", "server.rack"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Server") {
                    ServerStatusRow()
                }
                Section("Stat cards") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(metrics, id: \.title) { metric in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(metric.title, systemImage: metric.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(metric.value)
                                    .font(.title2.bold().monospacedDigit())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 14))
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section("Grant example") {
                    // Каноническая audit-строка гранта видна и здесь.
                    Text(AdminPreviewData.grantExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Section("Recent audit") {
                    ForEach(AdminPreviewData.audit) { entry in
                        AuditRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Overview")
        }
    }
}

// MARK: - ServerStatusRow

struct ServerStatusRow: View {
    @State private var health: String = "checking…"

    var body: some View {
        HStack {
            Circle()
                .fill(health == "ok" ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            Text("API /health: \(health)")
            Spacer()
            Button("Check") {
                Task { await check() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .task { await check() }
    }

    private func check() async {
        // TODO(backend): общий APIClient через Shared target; пока URLSession напрямую.
        let url = URL(string: "https://api.lumeo.example/health")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            health = (response as? HTTPURLResponse)?.statusCode == 200 ? "ok" : "error"
        } catch {
            health = "unreachable"
        }
    }
}

// MARK: - MetricRow / AuditRow (shared)

struct MetricRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
    }
}

struct AuditRow: View {
    var entry: AuditLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.actor) → \(entry.action)")
                .font(.subheadline.bold())
            Text("\(entry.target) · \(entry.at, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    OverviewView()
        .preferredColorScheme(.dark)
}

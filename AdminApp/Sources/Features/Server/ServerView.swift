// Lumeo Admin — Sources/Features/Server/ServerView.swift
// Сервер: CPU / RAM / storage / DB / WS / errors / uptime / CloudPub dot,
// /health, maintenance-режим, audit log.
// Prod-URL только из конфига сборки — хардкода CloudPub URL здесь нет.

import SwiftUI

// MARK: - ServerView

struct ServerView: View {
    @State private var apiHealth = "checking…"
    @State private var wsState = "disconnected"
    @State private var maintenance = false
    @State private var metrics = ServerMetrics.demo
    @State private var audit: [AuditLogEntry] = AdminPreviewData.audit

    var body: some View {
        NavigationStack {
            List {
                Section("Health") {
                    HStack {
                        Text("API /health")
                        Spacer()
                        Text(apiHealth).bold().foregroundStyle(apiHealth == "ok" ? .green : .secondary)
                    }
                    HStack {
                        Text("WS /ws (\(metrics.wsConnections) conn)")
                        Spacer()
                        Text(wsState).foregroundStyle(.secondary)
                    }
                    HStack {
                        // CloudPub dot: зелёная — онлайн, серая — недоступен.
                        Circle()
                            .fill(metrics.cloudPubOnline ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text("CloudPub relay")
                        Spacer()
                        Text(metrics.cloudPubOnline ? "online" : "offline")
                            .foregroundStyle(metrics.cloudPubOnline ? .green : .secondary)
                    }
                    Button("Recheck") {
                        Task { await check() }
                    }
                    .tint(.orange)
                }
                Section("Resources") {
                    MetricRow(title: "CPU", value: "\(Int(metrics.cpuPercent))%")
                    ProgressView(value: metrics.cpuPercent / 100).tint(.orange)
                    MetricRow(title: "RAM", value: "\(Int(metrics.ramPercent))%")
                    ProgressView(value: metrics.ramPercent / 100).tint(.orange)
                    MetricRow(title: "Storage", value: "\(Int(metrics.storagePercent))%")
                    ProgressView(value: metrics.storagePercent / 100).tint(.orange)
                    MetricRow(title: "DB latency", value: "\(metrics.dbLatencyMs) ms")
                    MetricRow(title: "Errors/min", value: "\(metrics.errorsPerMin)")
                    MetricRow(title: "Uptime", value: "\(Int(metrics.uptimeHours)) h")
                }
                Section("Config") {
                    MetricRow(title: "Environment", value: "staging")
                    MetricRow(title: "APIBaseURL", value: "from build config")
                    MetricRow(title: "WSBaseURL", value: "from build config")
                }
                Section("Maintenance") {
                    Toggle("Maintenance mode", isOn: $maintenance)
                        .onChange(of: maintenance) { _, enabled in
                            audit.insert(
                                AuditLogEntry(at: .now, actor: "admin:this-device",
                                              action: enabled ? "maintenance_on" : "maintenance_off",
                                              target: "server:api"),
                                at: 0
                            )
                            // TODO(backend): POST /api/v1/admin/server/maintenance.
                        }
                }
                Section("Audit") {
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    ForEach(audit) { AuditRow(entry: $0) }
                }
            }
            .navigationTitle("Server")
            .task { await check() }
        }
    }

    private func check() async {
        // TODO(shared): вынести в Shared APIClient; URL из конфига сборки, не хардкод.
        let url = URL(string: "https://api.lumeo.example/health")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            apiHealth = (response as? HTTPURLResponse)?.statusCode == 200 ? "ok" : "error"
        } catch {
            apiHealth = "unreachable"
        }
        wsState = "not probed (skeleton)"
    }
}

#Preview {
    ServerView()
        .preferredColorScheme(.dark)
}

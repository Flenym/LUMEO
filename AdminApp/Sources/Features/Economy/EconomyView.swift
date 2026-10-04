// Lumeo Admin — Sources/Features/Economy/EconomyView.swift
// Экономика EMBER (название конфигурируемо): grant/revoke, item create,
// ценники Workshop, ledger, Premium планы. Audit-строка:
// «Admin granted 500 EMBER to @x». Кейсы БЕЗ азарта. StoreKit — позже.

import SwiftUI

// MARK: - LedgerEntry

struct LedgerEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var at: Date = .now
    var user: String
    var delta: Int
    var reason: String
}

// MARK: - EconomyView

struct EconomyView: View {
    @State private var currencyName = "EMBER"
    @State private var grantTarget = "x"
    @State private var grantAmount = "500"
    @State private var itemTitle = ""
    @State private var itemPrice = "199"
    @State private var items: [(title: String, price: String)] = [
        ("Neon Frame", "199 EMBER"),
        ("Chat Glow", "349 EMBER"),
    ]
    @State private var ledger: [LedgerEntry] = [
        LedgerEntry(user: "@neo", delta: +199, reason: "theme_purchase"),
        LedgerEntry(user: "@mira", delta: +499, reason: "premium_monthly"),
        LedgerEntry(user: "@dex", delta: -50, reason: "case_open"),
    ]
    @State private var audit: [AuditLogEntry] = AdminPreviewData.audit

    var body: some View {
        NavigationStack {
            List {
                Section("Currency") {
                    HStack {
                        Text("Name")
                        Spacer()
                        // Конфигурируемое название валюты (синкается с Main App через backend config).
                        TextField("EMBER", text: $currencyName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }
                }
                Section("Grant / Revoke EMBER") {
                    HStack {
                        TextField("username", text: $grantTarget)
                            .textInputAutocapitalization(.never)
                        TextField("500", text: $grantAmount)
                            .keyboardType(.numbersAndPunctuation)
                            .frame(width: 80)
                        Button("Grant") { grant(revoke: false) }
                            .buttonStyle(.borderedProminent).tint(.green).controlSize(.small)
                        Button("Revoke") { grant(revoke: true) }
                            .buttonStyle(.bordered).tint(.red).controlSize(.small)
                    }
                    Text(EconomyGrant.canonicalExample)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Section("Item create") {
                    HStack {
                        TextField("Title", text: $itemTitle)
                        TextField("199", text: $itemPrice)
                            .keyboardType(.numberPad)
                            .frame(width: 70)
                        Button("Create") {
                            guard !itemTitle.isEmpty else { return }
                            items.append((itemTitle, "\(itemPrice) \(currencyName)"))
                            audit.insert(
                                AuditLogEntry(at: .now, actor: "admin:this-device",
                                              action: "create_item", target: "item:\(itemTitle)"),
                                at: 0
                            )
                            itemTitle = ""
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
                Section("Workshop prices") {
                    ForEach(items, id: \.title) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            Text(item.price).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
                Section("Premium plans") {
                    // Monthly / Six Months. Без Annual / Lifetime / Trial. Базу не блокирует.
                    PremiumPlanRow(name: "Monthly", price: "$4.99")
                    PremiumPlanRow(name: "Six Months", price: "$24.99")
                    PremiumPlanRow(name: "Group Premium ×3–5", price: "$12.99")
                }
                Section("Cases (no gambling: public drop tables)") {
                    // Кейсы без азарта: шансы видны ДО открытия.
                    Text("Drop tables are published in-app before purchase. No hidden odds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Ledger") {
                    ForEach(ledger) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.user).bold()
                                Text(entry.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.delta > 0 ? "+" : "")\(entry.delta) \(currencyName)")
                                .monospacedDigit()
                                .foregroundStyle(entry.delta >= 0 ? .green : .red)
                        }
                    }
                }
                Section("Audit") {
                    ForEach(audit) { AuditRow(entry: $0) }
                }
            }
            .navigationTitle("Economy")
        }
    }

    private func grant(revoke: Bool) {
        let raw = Int(grantAmount) ?? 500
        let amount = revoke ? -abs(raw) : abs(raw)
        let line = EconomyGrant.auditLine(admin: "admin:this-device", amount: amount, target: grantTarget, currency: currencyName)
        ledger.insert(LedgerEntry(user: "@\(grantTarget)", delta: amount, reason: revoke ? "admin_revoke" : "admin_grant"), at: 0)
        audit.insert(AuditLogEntry(at: .now, actor: "admin:this-device", action: line, target: "user:\(grantTarget)"), at: 0)
        // TODO(backend): POST /api/v1/admin/economy/grant {user, amount, idempotencyKey}.
    }
}

// MARK: - PremiumPlanRow

struct PremiumPlanRow: View {
    var name: String
    var price: String

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(price).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EconomyView()
        .preferredColorScheme(.dark)
}

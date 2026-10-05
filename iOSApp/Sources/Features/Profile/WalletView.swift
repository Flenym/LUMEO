// Lumeo — Sources/Features/Profile/WalletView.swift
// Tier4 монетизация UI: баланс EMBER, ledger history
// (transaction_id / from / to / item / amount / time / status),
// send / gift / sell / trade sheets, idempotency (повтор не дублирует).

import SwiftUI

// MARK: - WalletView

struct WalletView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var ledger = WalletLedger()
    @State private var balance = 1250
    @State private var sheet: WalletSheet?
    @State private var recipient = ""
    @State private var amountText = "100"

    enum WalletSheet: String, Identifiable {
        case send, gift, sell, trade
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section(String(localized: "wallet.balance")) {
                HStack {
                    Text("\(balance)")
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(theme.current.text)
                    Text("EMBER")
                        .font(.headline.bold())
                        .foregroundStyle(theme.current.primary)
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                HStack(spacing: 8) {
                    walletButton(key: "wallet.send", image: "paperplane.fill", sheet: .send)
                    walletButton(key: "wallet.gift", image: "gift.fill", sheet: .gift)
                    walletButton(key: "wallet.sell", image: "tag.fill", sheet: .sell)
                    walletButton(key: "wallet.trade", image: "arrow.left.arrow.right", sheet: .trade)
                }
                .buttonStyle(.bordered)
            }
            Section(String(localized: "wallet.history")) {
                if ledger.entries.isEmpty {
                    Text(String(localized: "wallet.empty"))
                        .foregroundStyle(theme.current.textSecondary)
                }
                ForEach(ledger.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.item ?? "transfer")
                                .font(.subheadline.bold())
                                .foregroundStyle(theme.current.text)
                            Spacer()
                            Text("\(entry.amount >= 0 ? "+" : "")\(entry.amount)")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(entry.amount >= 0 ? theme.current.success : theme.current.danger)
                        }
                        Text("tx:\(entry.transactionID) · \(entry.from) → \(entry.to)")
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.current.textSecondary)
                        Text("\(entry.at, style: .relative) · \(entry.status.rawValue)")
                            .font(.caption)
                            .foregroundStyle(theme.current.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(String(localized: "wallet.title"))
        .sheet(item: $sheet) { kind in
            NavigationStack {
                Form {
                    TextField("@username", text: $recipient)
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 44)
                    TextField("100", text: $amountText)
                        .keyboardType(.numberPad)
                        .frame(minHeight: 44)
                    Button(String(localized: "common.save")) {
                        commit(kind: kind)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                }
                .navigationTitle(String(localized: "wallet.\(kind.rawValue)"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .tint(theme.current.primary)
        }
        .onAppear { seedIfEmpty() }
    }

    private func walletButton(key: String, image: String, sheet: WalletSheet) -> some View {
        Button {
            self.sheet = sheet
        } label: {
            Label(String(localized: "\(key)"), systemImage: image)
                .frame(minHeight: 44)
        }
        .accessibilityLabel(String(localized: "\(key)"))
    }

    private func commit(kind: WalletSheet) {
        let amount = Int(amountText) ?? 0
        guard amount > 0, !recipient.isEmpty else { return }
        let delta = (kind == .sell) ? amount : -amount
        let key = "\(kind.rawValue):\(recipient):\(amount):\(amountText)"
        let entry = EmberLedgerEntry(
            transactionID: UUID().uuidString.prefix(8).lowercased(),
            from: "@you", to: recipient, item: kind.rawValue,
            amount: delta, status: .completed
        )
        if ledger.append(entry, idempotencyKey: key) {
            balance += delta
        }
        sheet = nil
        recipient = ""
    }

    private func seedIfEmpty() {
        guard ledger.entries.isEmpty else { return }
        var l = WalletLedger()
        _ = l.append(EmberLedgerEntry(
            transactionID: "a1b2c3d4", from: "@mira", to: "@you",
            item: "theme_purchase", amount: 199, at: .now.addingTimeInterval(-3600), status: .completed
        ), idempotencyKey: "seed-1")
        _ = l.append(EmberLedgerEntry(
            transactionID: "e5f6g7h8", from: "@you", to: "@dex",
            item: "gift", amount: -50, at: .now.addingTimeInterval(-7200), status: .completed
        ), idempotencyKey: "seed-2")
        ledger = l
    }
}

#Preview {
    NavigationStack { WalletView() }
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

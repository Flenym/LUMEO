// Lumeo — Sources/Features/Profile/StoreView.swift
// Tier4: купить / получить / подарить. Sandbox badge «admin-issued».

import SwiftUI

// MARK: - StoreView

struct StoreView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var items: [StoreItem] = [
        StoreItem(title: "Neon Frame", priceEmber: 199, isFree: false, isAdminIssued: false, canGift: true),
        StoreItem(title: "Starter Pack", priceEmber: 0, isFree: true, isAdminIssued: false, canGift: false),
        StoreItem(title: "Founder Border", priceEmber: 0, isFree: false, isAdminIssued: true, canGift: true),
        StoreItem(title: "Chat Glow", priceEmber: 349, isFree: false, isAdminIssued: false, canGift: true),
    ]
    @State private var toast: String?

    var body: some View {
        List {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(theme.current.text)
                        Spacer()
                        if item.isAdminIssued {
                            Text(String(localized: "store.sandbox"))
                                .font(.caption2.bold())
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.orange.opacity(0.25), in: .capsule)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(item.isFree ? String(localized: "workshop.free") : "\(item.priceEmber) EMBER")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.current.secondary)
                    HStack(spacing: 8) {
                        Button(item.isFree ? String(localized: "store.get") : String(localized: "store.buy")) {
                            toast = item.title
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.current.primary)
                        .controlSize(.small)
                        .frame(minHeight: 44)
                        Button(String(localized: "store.gift")) {
                            toast = item.title
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(minHeight: 44)
                        .disabled(!item.canGift)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.title)
            }
            if let toast {
                Section {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(String(localized: "store.title"))
    }
}

#Preview {
    NavigationStack { StoreView() }
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

// Lumeo — Sources/Features/Profile/GiftsInboxView.swift
// Tier4: Принять / Продать / Использовать / Передарить — по флагам item.

import SwiftUI

// MARK: - GiftsInboxView

struct GiftsInboxView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var gifts: [GiftItem] = [
        GiftItem(title: "Neon Frame", from: "@mira", canAccept: true, canSell: true, canUse: true, canRegift: true),
        GiftItem(title: "Founder Border", from: "@admin", canAccept: true, canSell: false, canUse: true, canRegift: false),
    ]

    var body: some View {
        List {
            Section(String(localized: "gifts.inbox")) {
                if gifts.isEmpty {
                    Text(String(localized: "gifts.empty"))
                        .foregroundStyle(theme.current.textSecondary)
                }
                ForEach(gifts) { gift in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(gift.title)
                                .font(.headline)
                                .foregroundStyle(theme.current.text)
                            Spacer()
                            Text(gift.from)
                                .font(.caption)
                                .foregroundStyle(theme.current.textSecondary)
                        }
                        HStack(spacing: 8) {
                            giftButton(key: "gifts.accept", enabled: gift.canAccept, tint: .green, gift: gift)
                            giftButton(key: "gifts.use", enabled: gift.canUse, tint: nil, gift: gift)
                            giftButton(key: "gifts.resell", enabled: gift.canSell, tint: nil, gift: gift)
                            giftButton(key: "gifts.regift", enabled: gift.canRegift, tint: nil, gift: gift)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(String(localized: "gifts.title"))
    }

    private func giftButton(key: String, enabled: Bool, tint: Color?, gift: GiftItem) -> some View {
        Button(String(localized: "\(key)")) {
            withAnimation { gifts.removeAll { $0.id == gift.id } }
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(.small)
        .frame(minHeight: 44)
        .disabled(!enabled)
        .accessibilityLabel(String(localized: "\(key)"))
    }
}

#Preview {
    NavigationStack { GiftsInboxView() }
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

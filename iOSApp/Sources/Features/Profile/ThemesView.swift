// Lumeo — Sources/Features/Profile/ThemesView.swift
// 10 официальных тем: preview screenshots (gradient-mock), apply/preview/save.
// White Minimal — светлая. Liquid Glass точечно (превью-карточки).

import SwiftUI

// MARK: - ThemesView

struct ThemesView: View {
    @Environment(ThemeManager.self) private var theme
    @Binding var selectedName: String
    @State private var preview: AppTheme?
    @State private var savedFlash = false

    init(selectedName: Binding<String>? = nil) {
        _selectedName = selectedName ?? .constant("OLED Orange")
    }

    var body: some View {
        List {
            Section(String(localized: "profile.themes.official")) {
                ForEach(AppTheme.all, id: \.name) { option in
                    ThemeRow(
                        option: option,
                        isSelected: selectedName == option.name,
                        onPreview: { preview = option },
                        onApply: {
                            selectedName = option.name
                            theme.apply(option)
                            savedFlash = true
                        }
                    )
                }
            }
            if savedFlash {
                Section {
                    Label(String(localized: "profile.themes.saved"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.current.background)
        .navigationTitle(String(localized: "profile.themes"))
        .sheet(item: $preview) { item in
            NavigationStack {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [item.background, item.surface, item.primary],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(height: 240)
                        .overlay {
                            VStack(spacing: 8) {
                                Circle().fill(item.surfaceSecondary).frame(width: 64, height: 64)
                                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.7)).frame(width: 160, height: 12)
                                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.4)).frame(width: 110, height: 10)
                            }
                        }
                    Text(item.name).font(.title2.bold())
                    Spacer()
                    HStack(spacing: 12) {
                        Button(String(localized: "common.back")) { preview = nil }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        Button(String(localized: "common.save")) {
                            selectedName = item.name
                            theme.apply(item)
                            preview = nil
                            savedFlash = true
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                    }
                }
                .padding()
                .navigationTitle(String(localized: "profile.themes.preview"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .tint(theme.current.primary)
        }
    }
}

// MARK: - ThemeRow (gradient-mock screenshot)

struct ThemeRow: View {
    var option: AppTheme
    var isSelected: Bool
    var onPreview: () -> Void
    var onApply: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Preview screenshot: gradient-mock из палитры темы.
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [option.background, option.surface, option.primary],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 64, height: 64)
                .overlay {
                    Circle()
                        .fill(option.primary)
                        .frame(width: 22, height: 22)
                        .overlay { Image(systemName: "person.fill").font(.caption2).foregroundStyle(.white) }
                        .offset(x: -14, y: 14)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(option.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                if isSelected {
                    Label(String(localized: "profile.themes.apply"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            Button(String(localized: "common.preview"), action: onPreview)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(minHeight: 44)
            Button(String(localized: "profile.themes.apply"), action: onApply)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(minHeight: 44)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(option.name)
    }
}

// Wrapper чтобы sheet(item:) работал с Identifiable темой.
extension AppTheme: Identifiable {
    var id: String { name }
}

#Preview {
    @Previewable @State var name = "OLED Orange"
    NavigationStack {
        ThemesView(selectedName: $name)
    }
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
}

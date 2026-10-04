// Lumeo — Sources/Features/Profile/ProfileEditorView.swift
// НОВЫЙ редактор: add/remove (кроме системных) / drag-drop reorder / resize handles /
// background / opacity / accent / decor. Long-press + .draggable, snapping, safe-area guard.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ProfileEditorView

struct ProfileEditorView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var layout: ProfileLayout
    @State private var draggedID: String?
    @State private var opacity: Double = 1.0
    @State private var accent: Color = .orange

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "profile.editor.hint")) {
                    ForEach($layout.blocks, id: \.id) { $block in
                        HStack(spacing: 10) {
                            Image(systemName: block.kind.isSystem ? "lock.fill" : "line.3.horizontal")
                                .foregroundStyle(theme.current.textSecondary)
                                .frame(width: 28, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "profile.block.\(block.kind.rawValue)"))
                                    .foregroundStyle(theme.current.text)
                                Text("x:\(block.x) y:\(block.y) · \(block.width)x\(block.height)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(theme.current.textSecondary)
                            }
                            Spacer()
                            // Resize handles: − / + (snapping к grid 12, clamp).
                            if !block.kind.isSystem {
                                Stepper(
                                    String(localized: "profile.editor.resize"),
                                    value: Binding(
                                        get: { block.width },
                                        set: { block.width = ProfileLayoutRules.clamped(span: $0) }
                                    ),
                                    in: ProfileLayoutRules.minSpan...ProfileLayoutRules.maxSpan
                                )
                                .labelsHidden()
                                .frame(minHeight: 44)
                            }
                        }
                        .draggable(block.id) // Long-press drag начало
                        .dropDestination(for: String.self) { items, _ in
                            guard let fromID = items.first,
                                  let from = layout.blocks.firstIndex(where: { $0.id == fromID }),
                                  let to = layout.blocks.firstIndex(where: { $0.id == block.id })
                            else { return false }
                            withAnimation {
                                layout.blocks.move(
                                    fromOffsets: IndexSet(integer: from),
                                    toOffset: to > from ? to + 1 : to
                                )
                                renumberY()
                            }
                            return true
                        } isTargeted: { _ in }
                        .accessibilityLabel(String(localized: "profile.block.\(block.kind.rawValue)"))
                    }
                    .onMove { from, to in
                        layout.blocks.move(fromOffsets: from, toOffset: to)
                        renumberY()
                    }
                    .onDelete { offsets in
                        // Guard: системные блоки неудаляемы.
                        let allowed = offsets.filter { !layout.blocks[$0].kind.isSystem }
                        layout.blocks.remove(atOffsets: IndexSet(allowed))
                        renumberY()
                    }
                }

                Section(String(localized: "common.add")) {
                    ForEach(ProfileBlockKind.allCases.filter { kind in
                        !layout.blocks.contains(where: { $0.kind == kind })
                    }, id: \.self) { kind in
                        Button {
                            addBlock(kind: kind)
                        } label: {
                            Label(String(localized: "profile.block.\(kind.rawValue)"), systemImage: "plus.circle")
                                .frame(minHeight: 44)
                        }
                        .disabled(!ProfileLayoutRules.canAdd(blocks: layout.blocks))
                    }
                }

                Section(String(localized: "profile.editor.theme")) {
                    Picker(String(localized: "profile.editor.theme"), selection: $layout.themeName) {
                        ForEach(AppTheme.all, id: \.name) { option in
                            Text(option.name).tag(option.name)
                        }
                    }
                    .onChange(of: layout.themeName) { _, new in
                        if ThemeResolver.themeExists(named: new) { theme.apply(named: new) }
                    }
                    NavigationLink(String(localized: "profile.themes")) {
                        ThemesView(selectedName: $layout.themeName)
                    }
                    .frame(minHeight: 44)
                }

                Section(String(localized: "profile.editor.background")) {
                    Slider(value: $opacity, in: 0.2...1.0) {
                        Text(String(localized: "profile.editor.opacity"))
                    }
                    .frame(minHeight: 44)
                    .onChange(of: opacity) { _, v in
                        layout.blocks.indices.forEach { i in
                            var p = layout.blocks[i].payload ?? [:]
                            p[ProfilePayloadKey.opacity] = String(format: "%.2f", v)
                            layout.blocks[i].payload = p
                        }
                    }
                    ColorPicker(String(localized: "profile.editor.accent"), selection: $accent)
                        .frame(minHeight: 44)
                    Picker(String(localized: "profile.editor.decor"), selection: $layout.effectID) {
                        Text("None").tag(nil as String?)
                        Text("Glow").tag("glow" as String?)
                        Text("Particles").tag("particles" as String?)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "profile.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton().frame(minWidth: 44, minHeight: 44) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
        .tint(theme.current.primary)
    }

    private func addBlock(kind: ProfileBlockKind) {
        let nextY = (layout.blocks.map(\.y).max() ?? 0) + 1
        layout.blocks.append(ProfileBlock(
            id: "\(kind.rawValue)-\(UUID().uuidString.prefix(4))",
            kind: kind, x: 0, y: nextY, width: 4, height: 1, payload: nil
        ))
        renumberY()
    }

    /// Snapping: y перенумеровываем по порядку (safe-area guard — без отрицательных).
    private func renumberY() {
        for i in layout.blocks.indices {
            layout.blocks[i].y = max(i, 0)
            layout.blocks[i].x = ProfileLayoutRules.clampedX(layout.blocks[i].x, span: layout.blocks[i].width)
            layout.blocks[i].width = ProfileLayoutRules.clamped(span: layout.blocks[i].width)
        }
    }
}

#Preview {
    @Previewable @State var layout = ProfileLayout.default
    ProfileEditorView(layout: $layout)
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

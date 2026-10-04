// Lumeo — Sources/Features/Workshop/WorkshopView.swift
// Workshop тем: официальные + user-made. Правило «5 бесплатных перед первой платной».
// Фильтры All/Free/Paid/Popular/New/Official, sort, search.
// Карточка: title/desc/preview/creator/version/price/category/compat/date.
// Detail + Preview без покупки + Применить/Назад/Сохранить.
// Create flow: 5-free-rule прогресс бар, submit → Pending UI, my-submissions статусы.
// Purchase через EMBER (ledger-заглушка, StoreKit — позже).

import SwiftUI

// MARK: - WorkshopFilter / Sort

enum WorkshopFilter: String, CaseIterable, Identifiable {
    case all, free, paid, popular, new, official
    var id: String { rawValue }
}

enum WorkshopSort: String, CaseIterable, Identifiable {
    case popular, newest, priceAsc, priceDesc
    var id: String { rawValue }
}

// MARK: - WorkshopTheme

struct WorkshopTheme: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var detailDescription: String
    var author: String
    var version: String
    var priceEmber: Int
    var category: String
    var compat: String
    var createdAt: Date
    var downloads: Int
    var isOfficial: Bool
    var isPublished: Bool
    var status: WorkshopStatus
    var palette: [Color]

    var isFree: Bool { priceEmber == 0 }
}

enum WorkshopStatus: String, Hashable {
    case published, pending, rejected
}

// MARK: - WorkshopView

struct WorkshopView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var filter: WorkshopFilter = .all
    @State private var sort: WorkshopSort = .popular
    @State private var query = ""
    @State private var selected: WorkshopTheme?
    @State private var showCreate = false
    @State private var showMine = false
    @State private var myFreeCount = 3
    @State private var submissions: [WorkshopTheme] = [
        WorkshopTheme(
            name: "Mono Draft", detailDescription: "Draft theme", author: "you",
            version: "0.9", priceEmber: 0, category: "Minimal",
            compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 2),
            downloads: 900, isOfficial: false, isPublished: false,
            status: .pending, palette: [.gray, .white]
        ),
    ]

    private let catalog: [WorkshopTheme] = [
        WorkshopTheme(name: "OLED Orange", detailDescription: "Default OLED + orange accent", author: "Lumeo", version: "2.0", priceEmber: 0, category: "Official", compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 90), downloads: 120_000, isOfficial: true, isPublished: true, status: .published, palette: [.black, .orange]),
        WorkshopTheme(name: "Pure Black", detailDescription: "True black minimal", author: "Lumeo", version: "2.0", priceEmber: 0, category: "Official", compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 80), downloads: 98_000, isOfficial: true, isPublished: true, status: .published, palette: [.black, .white]),
        WorkshopTheme(name: "Purple Glass", detailDescription: "Violet glass", author: "Lumeo", version: "1.4", priceEmber: 0, category: "Official", compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 60), downloads: 76_000, isOfficial: true, isPublished: true, status: .published, palette: [.purple, .blue]),
        WorkshopTheme(name: "White Minimal", detailDescription: "Light minimal theme", author: "Lumeo", version: "1.0", priceEmber: 0, category: "Official", compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 10), downloads: 41_000, isOfficial: true, isPublished: true, status: .published, palette: [.white, .blue]),
        WorkshopTheme(name: "Neon Grid", detailDescription: "Green grid on black", author: "mira", version: "1.2", priceEmber: 0, category: "Neon", compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 20), downloads: 12_400, isOfficial: false, isPublished: true, status: .published, palette: [.black, .green]),
        WorkshopTheme(name: "Sunset Duo", detailDescription: "Warm sunset gradient", author: "mira", version: "1.0", priceEmber: 199, category: "Gradient", compat: "iOS 18+", createdAt: .now.addingTimeInterval(-86400 * 5), downloads: 8_100, isOfficial: false, isPublished: true, status: .published, palette: [.orange, .pink]),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                sortBar
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(visible) { item in
                            WorkshopCard(item: item) { selected = item }
                        }
                    }
                    .padding()
                }
            }
            .background(theme.current.background)
            .navigationTitle(String(localized: "workshop.title"))
            .searchable(text: $query, prompt: String(localized: "workshop.search"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showMine = true
                    } label: {
                        Image(systemName: "tray.full.fill").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "workshop.my"))
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "workshop.create"))
                }
            }
            .sheet(item: $selected) { WorkshopDetailSheet(item: $0) }
            .sheet(isPresented: $showCreate) {
                WorkshopCreateSheet(freeCount: myFreeCount) { theme in
                    submissions.insert(theme, at: 0)
                    if theme.isFree { myFreeCount += 1 }
                    showCreate = false
                }
            }
            .sheet(isPresented: $showMine) {
                NavigationStack {
                    List {
                        ForEach(submissions) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name).bold()
                                    Text(statusText(item.status))
                                        .font(.caption)
                                        .foregroundStyle(item.status == .published ? .green : .orange)
                                }
                                Spacer()
                                Text("\(item.downloads)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .navigationTitle(String(localized: "workshop.my"))
                    .navigationBarTitleDisplayMode(.inline)
                }
                .tint(theme.current.primary)
            }
        }
    }

    private func statusText(_ status: WorkshopStatus) -> String {
        switch status {
        case .published: return String(localized: "workshop.published")
        case .pending: return String(localized: "workshop.pending")
        case .rejected: return String(localized: "workshop.rejected")
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkshopFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(String(localized: "workshop.filter.\(option.rawValue)"))
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(filter == option ? theme.current.primary : theme.current.surface, in: .capsule)
                            .foregroundStyle(filter == option ? .white : theme.current.text)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "workshop.filter.\(option.rawValue)"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var sortBar: some View {
        Picker(String(localized: "workshop.sort"), selection: $sort) {
            Text(String(localized: "workshop.sort.popular")).tag(WorkshopSort.popular)
            Text(String(localized: "workshop.sort.newest")).tag(WorkshopSort.newest)
            Text(String(localized: "workshop.sort.priceAsc")).tag(WorkshopSort.priceAsc)
            Text(String(localized: "workshop.sort.priceDesc")).tag(WorkshopSort.priceDesc)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var visible: [WorkshopTheme] {
        var list = catalog.filter { $0.isPublished }
        if !query.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.author.localizedCaseInsensitiveContains(query)
            }
        }
        switch filter {
        case .all: break
        case .free: list = list.filter(\.isFree)
        case .paid: list = list.filter { !$0.isFree }
        case .popular: list.sort { $0.downloads > $1.downloads }
        case .new: list.sort { $0.createdAt > $1.createdAt }
        case .official: list = list.filter(\.isOfficial)
        }
        switch sort {
        case .popular: list.sort { $0.downloads > $1.downloads }
        case .newest: list.sort { $0.createdAt > $1.createdAt }
        case .priceAsc: list.sort { $0.priceEmber < $1.priceEmber }
        case .priceDesc: list.sort { $0.priceEmber > $1.priceEmber }
        }
        return list
    }
}

// MARK: - WorkshopCard

struct WorkshopCard: View {
    @Environment(ThemeManager.self) private var theme
    var item: WorkshopTheme
    var onPreview: () -> Void

    var body: some View {
        Button(action: onPreview) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: item.palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 90)
                    .overlay(alignment: .topLeading) {
                        if item.isOfficial {
                            Label(String(localized: "workshop.official"), systemImage: "checkmark.seal.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.black.opacity(0.45), in: .capsule)
                                .padding(6)
                        }
                    }
                Text(item.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.current.text)
                    .lineLimit(1)
                Text("\(item.author) · v\(item.version)")
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
                    .lineLimit(1)
                Text(item.isFree ? String(localized: "workshop.free") : "\(item.priceEmber) EMBER")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.secondary)
            }
            .padding(10)
            .background(theme.current.surface, in: .rect(cornerRadius: 16))
        }
        .accessibilityLabel(item.name)
        .accessibilityHint(String(localized: "workshop.preview"))
    }
}

// MARK: - WorkshopDetailSheet (Detail + Preview без покупки)

struct WorkshopDetailSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    var item: WorkshopTheme
    @State private var applied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: item.palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 220)
                    Text(item.name).font(.title2.bold()).foregroundStyle(theme.current.text)
                    Text(item.detailDescription).font(.subheadline).foregroundStyle(theme.current.textSecondary)
                    detailRow(key: "common.author", value: item.author)
                    detailRow(key: "common.version", value: item.version)
                    detailRow(key: "common.price", value: item.isFree ? String(localized: "workshop.free") : "\(item.priceEmber) EMBER")
                    detailRow(key: "common.category", value: item.category)
                    detailRow(key: "workshop.compat", value: item.compat)
                    detailRow(key: "common.date", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
                    Spacer(minLength: 8)
                    HStack(spacing: 12) {
                        Button(String(localized: "workshop.back")) { dismiss() }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        Button(item.isFree
                            ? String(localized: "workshop.apply")
                            : "\(String(localized: "workshop.buy")) · \(item.priceEmber) EMBER") {
                            // Purchase через EMBER (ledger) + Применить.
                            applied = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.current.primary)
                        .frame(minHeight: 44)
                        Button(String(localized: "workshop.save")) { dismiss() }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                    }
                    if applied {
                        Label(String(localized: "profile.themes.saved"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding()
            }
            .background(theme.current.background)
            .navigationTitle(String(localized: "workshop.preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
        .tint(theme.current.primary)
    }

    private func detailRow(key: String, value: String) -> some View {
        HStack {
            Text(String(localized: "\(key)")).foregroundStyle(theme.current.textSecondary)
            Spacer()
            Text(value).foregroundStyle(theme.current.text).monospacedDigit()
        }
        .font(.subheadline)
    }
}

// MARK: - WorkshopCreateSheet (5-free-rule + Pending UI)

struct WorkshopCreateSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    var freeCount: Int
    var onSubmit: (WorkshopTheme) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var priceText = "0"
    @State private var submitted = false

    private var price: Int { Int(priceText) ?? 0 }
    private var canPublishPaid: Bool { WorkshopRules.canPublishPaid(freeCount: freeCount) }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "workshop.create")) {
                    TextField(String(localized: "workshop.title"), text: $name)
                        .frame(minHeight: 44)
                    TextField(String(localized: "workshop.description"), text: $description)
                        .frame(minHeight: 44)
                    TextField("EMBER", text: $priceText)
                        .keyboardType(.numberPad)
                        .frame(minHeight: 44)
                }
                Section(String(localized: "workshop.fiveFree")) {
                    // Прогресс бар «3/5».
                    ProgressView(value: WorkshopRules.freeProgress(freeCount: freeCount)) {
                        Text(WorkshopRules.freeProgressText(freeCount: freeCount))
                            .monospacedDigit()
                    }
                    .tint(theme.current.primary)
                    if price > 0 && !canPublishPaid {
                        Label(
                            "\(String(localized: "workshop.fiveFree")): \(WorkshopRules.freeProgressText(freeCount: freeCount))",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else if canPublishPaid {
                        Label(String(localized: "workshop.fiveFree.done"), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Section {
                    Button(String(localized: "workshop.submit")) {
                        let theme = WorkshopTheme(
                            name: name.isEmpty ? "Untitled" : name,
                            detailDescription: description,
                            author: "you", version: "1.0",
                            priceEmber: price, category: "Custom",
                            compat: "iOS 18+", createdAt: .now,
                            downloads: 0, isOfficial: false,
                            isPublished: false, status: .pending,
                            palette: [.gray, .blue]
                        )
                        submitted = true
                        onSubmit(theme)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .disabled(name.isEmpty || (price > 0 && !canPublishPaid))
                }
                if submitted {
                    Section(String(localized: "workshop.pending")) {
                        Label(String(localized: "workshop.pending"), systemImage: "hourglass")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(String(localized: "workshop.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
        .tint(theme.current.primary)
    }
}

#Preview {
    WorkshopView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

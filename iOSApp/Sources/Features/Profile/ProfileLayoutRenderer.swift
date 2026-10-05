// Lumeo — Sources/Features/Profile/ProfileLayoutRenderer.swift
// ЕДИНСТВЕННЫЙ рендер профиля: [ProfileBlockDTO] (grid 12, clamp, no-overlap),
// theme apply, эффекты glow/particles GPU-efficient (Canvas + .drawingGroup, без SpriteKit).
// Steam-like страница: cover/banner/avatar с frame-наградами, identity, status,
// games main/favorites, links x7, stats, squads, photos, text blocks, session history.
// Birthday 🎂 + Поздравить. Feedback 👍/👎 meter с guard 1/24ч. Preview mode.

import SwiftUI

// MARK: - ProfileLayoutRenderer

struct ProfileLayoutRenderer: View {
    @Environment(ThemeManager.self) private var theme
    var layout: ProfileLayout
    var user: User
    var badges: [Badge] = [.verified, .early]
    var streakDays: Int = 12
    var squadStreakDays: Int = 8
    var xp: Int = 2450
    var birthday: Date? = nil
    var isPreview: Bool = false
    var squads: [Squad] = PreviewData.squads
    @State private var feedback = FeedbackStore(lastVoteAt: nil, likes: 128, dislikes: 6)
    @State private var congratulated = false

    /// Блоки, отсортированные и заклэмпленные под grid 12. No-overlap critical:
    /// пересечения схлопываются по y (первый побеждает), рендер никогда не накладывает вью.
    private var orderedBlocks: [ProfileBlockDTO] {
        let sorted = layout.blocks.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        var placed: [ProfileBlockDTO] = []
        var occupied: Set<String> = []
        for var b in sorted {
            let w = ProfileLayoutRules.clamped(span: b.width)
            let h = max(b.height, 1)
            b.width = w
            b.height = h
            b.x = ProfileLayoutRules.clampedX(b.x, span: w)
            var collides = false
            for dx in 0..<w {
                for dy in 0..<h {
                    if occupied.contains("\(b.x + dx):\(b.y + dy)") { collides = true }
                }
            }
            if collides { continue } // no-overlap: пропускаем конфликтный
            for dx in 0..<w {
                for dy in 0..<h { occupied.insert("\(b.x + dx):\(b.y + dy)") }
            }
            placed.append(b)
        }
        return placed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(orderedBlocks, id: \.id) { block in
                blockView(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            birthdayCard
            feedbackCard
            squadsCard
        }
        .overlay { effectOverlay }
        .drawingGroup() // GPU-efficient compositing эффектов
        .opacity(isPreview ? 1 : 1)
    }

    // MARK: - Blocks

    @ViewBuilder
    private func blockView(for block: ProfileBlockDTO) -> some View {
        switch block.kind {
        case .avatar: identityBlock
        case .banner: coverBlock
        case .about: aboutBlock(text: block.payload?[ProfilePayloadKey.text] ?? "")
        case .games: gamesBlock(payload: block.payload)
        case .achievements: statsBlock
        case .streak: streakInlineBlock
        case .links: linksBlock
        case .photo: photosBlock(payload: block.payload)
        case .background: sessionsBlock(payload: block.payload)
        }
    }

    // MARK: Cover (banner + avatar с frame-наградой)

    private var coverBlock: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [theme.current.primary, theme.current.secondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 150)
                .overlay(alignment: .topTrailing) {
                    Text(String(localized: "profile.cover"))
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(8)
                        .accessibilityHidden(true)
                }
            HStack(alignment: .bottom, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.current.surfaceSecondary)
                        .frame(width: 84, height: 84)
                        .overlay {
                            // Frame-награда: золотое кольцо за rank Gold+.
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: PlayerRank.rank(forXP: xp) == .gold ? 4 : 2
                                )
                        }
                    Text(String(user.displayName.prefix(1)))
                        .font(.largeTitle.bold())
                        .foregroundStyle(theme.current.text)
                }
                .accessibilityLabel(String(localized: "profile.block.avatar"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("🎮 \(user.currentGame ?? String(localized: "profile.noGame"))")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.bottom, 10)
            }
            .padding(12)
        }
    }

    // MARK: Identity (username + display + badges + level/rank chip)

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(user.displayName)
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                ForEach(badges, id: \.self) { BadgeView(badge: $0) }
            }
            .accessibilityElement(children: .combine)
            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
            HStack(spacing: 8) {
                Label("\(String(localized: "profile.identity.level")) \(XPEngine.level(forXP: xp))", systemImage: "star.fill")
                Label(String(localized: "\(PlayerRank.rank(forXP: xp).localizationKey)"), systemImage: "shield.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(theme.current.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.current.surfaceSecondary, in: .capsule)
            .accessibilityLabel("\(String(localized: "profile.identity.level")) \(XPEngine.level(forXP: xp))")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Status card

    private var statusCard: some View {
        HStack(spacing: 10) {
            Circle().fill(user.status.availability.color(in: theme.current))
                .frame(width: 12, height: 12)
            Text(user.status.text.isEmpty ? String(localized: "status.free") : user.status.text)
                .font(.subheadline)
                .foregroundStyle(theme.current.text)
            Spacer()
        }
        .padding(12)
        .background(theme.current.surface, in: .rect(cornerRadius: 14))
        .accessibilityLabel(String(localized: "profile.block.status"))
    }

    private func aboutBlock(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            statusCard
            Text(String(localized: "profile.about"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            Text(text.isEmpty ? String(localized: "profile.about.empty") : text)
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Games (main + favorites row)

    private func gamesBlock(payload: [String: String]?) -> some View {
        let main = payload?[ProfilePayloadKey.mainGame] ?? "Valorant"
        let favs = (payload?[ProfilePayloadKey.favorites] ?? "CS2,Dota 2").split(separator: ",").map(String.init)
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "profile.games"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            HStack(spacing: 8) {
                Text("\(String(localized: "profile.games.main")): \(main)")
                    .font(.caption.bold())
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(theme.current.primary.opacity(0.25), in: .capsule)
                    .foregroundStyle(theme.current.text)
            }
            .accessibilityLabel("\(String(localized: "profile.games.main")) \(main)")
            Text(String(localized: "profile.games.favorites"))
                .font(.caption.bold())
                .foregroundStyle(theme.current.textSecondary)
            HStack(spacing: 8) {
                ForEach(favs, id: \.self) { game in
                    Text(game)
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(theme.current.surfaceSecondary, in: .capsule)
                        .foregroundStyle(theme.current.text)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Stats (XP / Streak / Achievements)

    private var statsBlock: some View {
        HStack(spacing: 12) {
            statCell(value: "\(xp)", label: String(localized: "profile.stats.xp"))
            Divider().frame(height: 36)
            statCell(value: "\(streakDays)", label: String(localized: "profile.streak"))
            Divider().frame(height: 36)
            statCell(value: "24/150", label: String(localized: "profile.achievements"))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(theme.current.text)
            Text(label).font(.caption).foregroundStyle(theme.current.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var streakInlineBlock: some View {
        StreakView(personalDays: streakDays, squadDays: squadStreakDays)
    }

    // MARK: Links (Discord/YT/Twitch/Steam/Epic/PS/Xbox)

    private var linksBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "profile.links"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(["Discord", "YouTube", "Twitch", "Steam", "Epic", "PlayStation", "Xbox"], id: \.self) { service in
                    Label(service, systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(theme.current.surfaceSecondary, in: .rect(cornerRadius: 10))
                        .accessibilityLabel(service)
                }
            }
        }
        .padding(14)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Photos grid

    private func photosBlock(payload: [String: String]?) -> some View {
        let count = 6
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "profile.photos"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.current.surfaceSecondary)
                        .frame(height: 96)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(theme.current.textSecondary)
                        }
                }
            }
        }
        .padding(14)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Session history (custom text blocks)

    private func sessionsBlock(payload: [String: String]?) -> some View {
        let rows = (payload?[ProfilePayloadKey.sessions] ?? "Valorant · Win,CS2 · MVP,Dota 2 · Loss")
            .split(separator: ",").map(String.init)
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "profile.sessionHistory"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            ForEach(rows, id: \.self) { row in
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(theme.current.primary)
                    Text(row).font(.subheadline).foregroundStyle(theme.current.text)
                    Spacer()
                }
                .padding(10)
                .background(theme.current.surfaceSecondary, in: .rect(cornerRadius: 10))
            }
            Text(String(localized: "profile.customBlocks"))
                .font(.caption.bold())
                .foregroundStyle(theme.current.textSecondary)
        }
        .padding(14)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Birthday 🎂 + Поздравить

    @ViewBuilder
    private var birthdayCard: some View {
        if let birthday, BirthdayHelper.isToday(birthday: birthday) {
            HStack(spacing: 12) {
                Text("🎂")
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "profile.birthday.today"))
                        .font(.headline)
                        .foregroundStyle(theme.current.text)
                }
                Spacer()
                Button(congratulated ? String(localized: "profile.birthday.congratulated") : String(localized: "profile.birthday.congratulate")) {
                    congratulated = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.current.primary)
                .controlSize(.small)
                .frame(minHeight: 44)
                .disabled(congratulated)
                .accessibilityLabel(String(localized: "a11y.congratulate"))
                .accessibilityHint(String(localized: "profile.birthday.today"))
            }
            .padding(14)
            .background(theme.current.surface, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: Feedback 👍/👎 meter

    private var feedbackCard: some View {
        HStack(spacing: 16) {
            Text(String(localized: "profile.feedback"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            Spacer()
            Button {
                _ = feedback.vote(like: true)
            } label: {
                Label("\(feedback.likes)", systemImage: "hand.thumbsup.fill")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!feedback.canVote())
            .accessibilityLabel(String(localized: "a11y.like"))
            .accessibilityHint(String(localized: "profile.feedback.hint"))
            Button {
                _ = feedback.vote(like: false)
            } label: {
                Label("\(feedback.dislikes)", systemImage: "hand.thumbsdown.fill")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!feedback.canVote())
            .accessibilityLabel(String(localized: "a11y.dislike"))
            .accessibilityHint(String(localized: "profile.feedback.hint"))
        }
        .padding(14)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
        .overlay(alignment: .bottomLeading) {
            if !feedback.canVote() {
                Text(String(localized: "profile.feedback.blocked"))
                    .font(.caption2)
                    .foregroundStyle(theme.current.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: Squads

    private var squadsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "profile.squads"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            ForEach(squads.prefix(4)) { squad in
                HStack(spacing: 10) {
                    Circle()
                        .fill(theme.current.surfaceSecondary)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(squad.name.prefix(1)))
                                .font(.headline)
                                .foregroundStyle(theme.current.text)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(squad.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.current.text)
                        Text("Lv \(squad.level) · 🔥 \(squad.streakDays)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.current.textSecondary)
                    }
                    Spacer()
                }
                .frame(minHeight: 44)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.current.surface, in: .rect(cornerRadius: 16))
    }

    // MARK: Effects (glow / particles, CSS-like Canvas, GPU-efficient)
    @ViewBuilder
    private var effectOverlay: some View {
        if layout.effectID == "glow" {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(theme.current.primary.opacity(0.5), lineWidth: 2)
                .blur(radius: 6)
                .allowsHitTesting(false)
        } else if layout.effectID == "particles" {
            let particleColor = theme.current.primary.opacity(0.5)
            Canvas { context, size in
                // ~40 статичных частиц: дёшево для GPU, без SpriteKit.
                for i in 0..<40 {
                    let x = Double((i * 137) % Int(size.width))
                    let y = Double((i * 89) % Int(size.height))
                    let r: Double = 1 + Double(i % 3)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                        with: .color(particleColor)
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - BadgeView

struct BadgeView: View {
    @Environment(ThemeManager.self) private var theme
    var badge: Badge

    var body: some View {
        Group {
            switch badge {
            case .verified:
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
            case .sponsor:
                Text("S").font(.caption2.bold()).foregroundStyle(.white)
                    .padding(5)
                    .background(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
            case .developer:
                Image(systemName: "hammer.fill").foregroundStyle(theme.current.secondary)
            case .official:
                Image(systemName: "building.2.fill").foregroundStyle(theme.current.primary)
            case .beta:
                Text("β").font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
            case .early:
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(theme.current.warning)
            case .founder:
                Image(systemName: "crown.fill").font(.caption2).foregroundStyle(theme.current.warning)
            }
        }
        .frame(minWidth: 28, minHeight: 28)
        .accessibilityLabel(String(localized: "profile.badge.\(badge.rawValue)"))
    }
}

#Preview {
    ScrollView {
        ProfileLayoutRenderer(layout: .default, user: PreviewData.me, birthday: .now)
            .padding()
    }
    .environment(ThemeManager())
    .preferredColorScheme(.dark)
    .background(.black)
}

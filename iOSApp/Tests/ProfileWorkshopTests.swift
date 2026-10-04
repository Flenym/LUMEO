// Lumeo — Tests/ProfileWorkshopTests.swift
// XCTest: block limits, system-block delete запрещён, 5-free rule, theme apply.
import XCTest

@testable import LumeoApp

// MARK: - ProfileLayoutRulesTests

final class ProfileLayoutRulesTests: XCTestCase {
    /// Лимит блоков: больше maxBlocks добавить нельзя.
    func testBlockLimit() {
        let blocks = (0..<ProfileLayoutRules.maxBlocks).map {
            ProfileBlock(id: "b\($0)", kind: .photo, x: 0, y: $0, width: 4, height: 1, payload: nil)
        }
        XCTAssertFalse(ProfileLayoutRules.canAdd(blocks: blocks))
        XCTAssertTrue(ProfileLayoutRules.canAdd(blocks: Array(blocks.dropLast())))
    }

    /// Системные блоки (avatar/banner/about) удалять запрещено; остальные — можно.
    func testSystemBlockDeleteForbidden() {
        XCTAssertFalse(ProfileLayoutRules.canDelete(kind: .avatar))
        XCTAssertFalse(ProfileLayoutRules.canDelete(kind: .banner))
        XCTAssertFalse(ProfileLayoutRules.canDelete(kind: .about))
        XCTAssertTrue(ProfileLayoutRules.canDelete(kind: .games))
        XCTAssertTrue(ProfileLayoutRules.canDelete(kind: .photo))
        XCTAssertTrue(ProfileLayoutRules.canDelete(kind: .links))
    }

    /// Clamp размеров: span в 1...12, x не вылезает за grid.
    func testSizesClamp() {
        XCTAssertEqual(ProfileLayoutRules.clamped(span: 99), 12)
        XCTAssertEqual(ProfileLayoutRules.clamped(span: 0), 1)
        XCTAssertEqual(ProfileLayoutRules.clampedX(11, span: 4), 8)
    }

    /// No-overlap: пересекающиеся блоки детектятся.
    func testNoOverlapDetection() {
        let a = ProfileBlock(id: "a", kind: .games, x: 0, y: 0, width: 6, height: 1, payload: nil)
        let b = ProfileBlock(id: "b", kind: .photo, x: 4, y: 0, width: 6, height: 1, payload: nil)
        XCTAssertTrue(ProfileLayoutRules.hasOverlap([a, b]))
        let c = ProfileBlock(id: "c", kind: .photo, x: 6, y: 0, width: 6, height: 1, payload: nil)
        XCTAssertFalse(ProfileLayoutRules.hasOverlap([a, c]))
    }
}

// MARK: - WorkshopRulesTests (5-free rule)

final class WorkshopRulesTests: XCTestCase {
    /// Платная публикация только при ≥5 бесплатных.
    func testFiveFreeRule() {
        XCTAssertFalse(WorkshopRules.canPublishPaid(freeCount: 0))
        XCTAssertFalse(WorkshopRules.canPublishPaid(freeCount: 4))
        XCTAssertTrue(WorkshopRules.canPublishPaid(freeCount: 5))
        XCTAssertTrue(WorkshopRules.canPublishPaid(freeCount: 9))
    }

    /// Прогресс-бар «3/5».
    func testFreeProgressText() {
        XCTAssertEqual(WorkshopRules.freeProgressText(freeCount: 3), "3/5")
        XCTAssertEqual(WorkshopRules.freeProgressText(freeCount: 5), "5/5")
    }
}

// MARK: - ThemeResolverTests

final class ThemeResolverTests: XCTestCase {
    /// Apply официальной темы: 10 тем, включая White Minimal.
    func testThemeApply() {
        XCTAssertTrue(ThemeResolver.themeExists(named: "OLED Orange"))
        XCTAssertTrue(ThemeResolver.themeExists(named: "White Minimal"))
        XCTAssertFalse(ThemeResolver.themeExists(named: "Nope"))
        XCTAssertEqual(AppTheme.officialTen.count, 10)
        XCTAssertEqual(ThemeResolver.resolve(named: "White Minimal").name, "White Minimal")
    }
}

// MARK: - FeedbackStoreTests (1/24h guard)

final class FeedbackStoreTests: XCTestCase {
    func testOneVotePer24h() {
        var store = FeedbackStore(lastVoteAt: nil, likes: 0, dislikes: 0)
        XCTAssertTrue(store.vote(like: true))
        XCTAssertFalse(store.vote(like: true))
        XCTAssertFalse(store.canVote(now: .now.addingTimeInterval(3600)))
        XCTAssertTrue(store.canVote(now: .now.addingTimeInterval(25 * 3600)))
    }
}

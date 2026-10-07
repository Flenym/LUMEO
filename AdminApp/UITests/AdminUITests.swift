//
// AdminUITests.swift — admin critical flow: overview → users → ban → audit.
// Run: xcodebuild test -scheme LumeoAdmin.
// Admin app honors `--uitesting`: stubbed admin auth (pre-registered device),
// metadata-only fixtures, and accessibilityIdentifiers below.
//
import XCTest

/// См. комментарий в LumeoUITests: Xcode 26 требует @MainActor для XCUI.
@MainActor
final class AdminUITests: XCTestCase {
    var app: XCUIApplication!

    /// Async setUp: см. комментарий в LumeoUITests (MainActor + Swift 6).
    override func setUp() async throws {
        // Без super.setUp(): см. комментарий в LumeoUITests.
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launchEnvironment["API_BASE_URL"] = "http://localhost:5267"
    }

    /// Ждать ухода клавиатуры (анимация скрытия ~0.3с, на холодном дольше).
    private func waitNoKeyboard(timeout: TimeInterval = 15) {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.element
        )
        _ = XCTWaiter().wait(for: [gone], timeout: timeout)
    }

    // Холодный симулятор открывается 10-20с: таймаут с запасом.
    private func wait(_ id: String, timeout: TimeInterval = 25) -> XCUIElement {
        let el = app.descendants(matching: .any)[id]
        if !el.waitForExistence(timeout: timeout) {
            // Диагностика: что реально на экране (обрезано до 30К).
            print("HIERARCHY DUMP for missing \(id):")
            print(String(app.debugDescription.prefix(30000)))
        }
        XCTAssertTrue(el.exists, "Missing element: \(id)")
        return el
    }

    /// Тап по первому hittable среди совпадений: тулбар-кнопки iOS иногда
    /// дублирует в иерархии (видимая + зеркало), слепой tap падает с
    /// "Multiple matching elements found".
    private func tapFirstHittable(_ id: String) {
        _ = wait(id)
        let all = app.buttons.matching(identifier: id).allElementsBoundByIndex
        if let target = all.first(where: { $0.isHittable }) {
            target.tap()
        } else {
            print("HIERARCHY DUMP (no hittable \(id), count=\(all.count)):")
            print(String(app.debugDescription.prefix(15000)))
            app.buttons.matching(identifier: id).firstMatch.tap()
        }
    }

    func testOverviewUsersBanAudit() throws {
        app.launch()
        // Overview dashboard loads.
        XCTAssertTrue(wait("admin.overview").exists)
        XCTAssertTrue(wait("admin.overview.metrics").exists)

        // Users list -> open flagged user.
        wait("admin.tab.users").tap()
        wait("admin.users.search").tap()
        app.textFields["admin.users.search"].typeText("reported_user")
        // Скрыть клавиатуру (иначе перекрывает строку и тап не hittable).
        app.keyboards.buttons["Search"].tap()
        waitNoKeyboard()
        tapFirstHittable("admin.users.row")
        // Лист перестраивается после фильтра — первый тап может промахнуться
        // по уехавшим координатам: повторяем тап если шит не открылся.
        if !app.descendants(matching: .any)["admin.user.detail"].waitForExistence(timeout: 5) {
            tapFirstHittable("admin.users.row")
        }
        // Шит деталей открылся (иначе ban искать бессмысленно — точная диагностика).
        XCTAssertTrue(wait("admin.user.detail").exists)

        // Ban with reason (metadata-only review, no E2EE plaintext visible).
        wait("admin.user.ban").tap()
        wait("admin.user.ban.reason").tap()
        wait("admin.user.ban.confirm").tap()
        XCTAssertTrue(wait("admin.user.banned").exists)
        XCTAssertFalse(app.staticTexts["admin.user.plaintext"].exists,
                       "Admin must never see E2EE plaintext")

        // Audit log contains the ban entry.
        wait("admin.tab.audit").tap()
        XCTAssertTrue(wait("admin.audit.banEntry").exists)
    }
}

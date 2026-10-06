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

    func testOverviewUsersBanAudit() throws {
        app.launch()
        // Overview dashboard loads.
        XCTAssertTrue(wait("admin.overview").exists)
        XCTAssertTrue(wait("admin.overview.metrics").exists)

        // Users list -> open flagged user.
        wait("admin.tab.users").tap()
        wait("admin.users.search").tap()
        app.textFields["admin.users.search"].typeText("reported_user")
        wait("admin.users.row").tap()
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

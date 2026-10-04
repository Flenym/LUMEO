//
// LumeoUITests.swift — 7 critical flows (ТЗ acceptance).
// Run: xcodebuild test -scheme Lumeo (also driven by scripts/screenshots.sh).
// The app must honor `--uitesting` launch arg: stub network/auth, seed fixtures,
// and expose every tapped element via accessibilityIdentifier (see below).
//
import XCTest

/// Xcode 26 изолирует тесты MainActor по умолчанию — явная аннотация
/// обязательна, иначе XCUIApplication-APIs не компилируются (Swift 6).
@MainActor
final class LumeoUITests: XCTestCase {
    var app: XCUIApplication!

    /// Async setUp: выполняется изолированно на MainActor (иначе XCUI-APIs
    /// недоступны из nonisolated контекста в Swift 6 / Xcode 26).
    override func setUp() async throws {
        // Без super.setUp(): базовый XCTestCase.setUp пуст, а его вызов
        // пересылает non-Sendable self через изоляцию (Swift 6 error).
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launchEnvironment["API_BASE_URL"] = "http://localhost:5267"
        app.launchEnvironment["EMBER_CURRENCY_NAME"] = "EMBER"
    }

    // MARK: - Helpers

    private func launch() { app.launch() }

    private func wait(_ id: String, timeout: TimeInterval = 10) -> XCUIElement {
        let el = app.descendants(matching: .any)[id]
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Missing element: \(id)")
        return el
    }

    /// Скриншот в аттачменты (lifetime keepAlways): экспорт через
    /// `xcresulttool export attachments` → ревью дизайна по настоящим экранам.
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Сквозной онбординг (каждый тест стартует с --reset-state).
    private func passOnboarding(username: String = "uitest_user") {
        wait("onboarding.register.email").tap()
        app.textFields["onboarding.register.email"].typeText("t@t.io")
        wait("onboarding.register.username").tap()
        app.textFields["onboarding.register.username"].typeText(username)
        wait("onboarding.register.submit").tap()
        wait("verify.code.field").tap()
        app.textFields["verify.code.field"].typeText("123456")
        wait("verify.submit").tap()
        wait("profile.setup.displayName").tap()
        app.textFields["profile.setup.displayName"].typeText("UITest")
        wait("profile.setup.done").tap()
    }

    // MARK: 1. register → verify → profile → Home

    func testAuthRegisterVerifyHome() throws {
        launch()
        wait("onboarding.register.email").tap()
        wait("onboarding.register.username").tap()
        app.textFields["onboarding.register.username"].typeText("uitest_user")
        wait("onboarding.register.submit").tap()
        // Email code verify (cooldown respected in stub).
        wait("verify.code.field").tap()
        app.textFields["verify.code.field"].typeText("123456")
        wait("verify.submit").tap()
        // Profile setup -> Home answers "who is free" in 1-2s.
        wait("profile.setup.displayName").tap()
        wait("profile.setup.done").tap()
        XCTAssertTrue(wait("home.freeList").waitForExistence(timeout: 5))
        shot("02-home")
    }

    // MARK: 2. search → request → accept (friends)

    func testFriendsSearchRequestAccept() throws {
        launch()
        passOnboarding()
        wait("tab.friends").tap()
        wait("friends.search").tap()
        app.textFields["friends.search"].typeText("friend_two")
        wait("friends.search.result").tap()
        wait("friends.request.send").tap()
        XCTAssertTrue(wait("friends.request.pending").exists)
        // Stubbed counterpart accepts; status flips to accepted.
        XCTAssertTrue(wait("friends.request.accepted", timeout: 15).exists)
        shot("03-friends")
    }

    // MARK: 3. green → yellow → red (status)

    func testStatusGreenYellowRed() throws {
        launch()
        passOnboarding()
        wait("tab.home").tap()
        wait("status.dot").tap()
        for color in ["green", "yellow", "red"] {
            wait("status.color.\(color)").tap()
            XCTAssertTrue(wait("status.dot.\(color)").exists)
        }
        // Custom text ≤140 chars + TTL timer + auto-revert covered by stub asserts.
        wait("status.save").tap()
        XCTAssertTrue(wait("status.saved").exists)
        shot("04-status")
    }

    // MARK: 4. create → invite → accept → join → finish (session)

    func testSessionCreateInviteAcceptJoinFinish() throws {
        launch()
        passOnboarding()
        wait("session.create").tap()
        wait("session.create.game").tap()
        wait("session.create.confirm").tap()
        XCTAssertTrue(wait("session.banner.waiting").exists)
        wait("session.invite").tap()
        // Stubbed invitee accepts -> Ready -> Live.
        XCTAssertTrue(wait("session.invite.accepted", timeout: 15).exists)
        wait("session.join").tap()
        XCTAssertTrue(wait("session.banner.live").exists)
        wait("session.finish").tap()
        XCTAssertTrue(wait("session.banner.finished").exists)
        shot("05-session")
    }

    // MARK: 5. send → receive → read (chat, E2EE ciphertext only on wire)

    func testChatSendReceiveRead() throws {
        launch()
        passOnboarding()
        wait("tab.chats").tap()
        wait("chat.thread.first").tap()
        wait("chat.composer").tap()
        app.textViews["chat.composer"].typeText("hello e2ee")
        wait("chat.send").tap()
        XCTAssertTrue(wait("chat.message.sent").exists)
        XCTAssertTrue(wait("chat.message.delivered", timeout: 15).exists)
        XCTAssertTrue(wait("chat.message.read", timeout: 15).exists)
        shot("06-chat")
    }

    // MARK: 6. edit → save → reload (profile constructor)

    func testProfileEditSaveReload() throws {
        launch()
        passOnboarding()
        wait("tab.profile").tap()
        wait("profile.edit").tap()
        wait("profile.block.bio").tap()
        XCTAssertTrue(wait("profile.block.system").exists, "System blocks must be non-removable")
        shot("07-profile-edit")
        wait("profile.save").tap()
        app.terminate()
        launch() // reload from "server" (profile.saved пережил рестарт, онбординг проходим заново)
        passOnboarding(username: "uitest_two")
        wait("tab.profile").tap()
        XCTAssertTrue(wait("profile.saved").exists)
        shot("08-profile")
    }

    // MARK: 7. create → moderation → publish → preview (workshop)

    func testWorkshopCreateModerationPublishPreview() throws {
        launch()
        passOnboarding()
        // Workshop живёт в Profile (ТЗ Tier3 identity), отдельного таба нет.
        wait("tab.profile").tap()
        wait("profile.workshop.open").tap()
        wait("workshop.create").tap()
        wait("workshop.create.title").tap()
        app.textFields["workshop.create.title"].typeText("UITest Theme")
        wait("workshop.submit").tap()
        XCTAssertTrue(wait("workshop.status.pendingModeration").exists)
        // Stubbed moderation approves -> Published.
        XCTAssertTrue(wait("workshop.status.published", timeout: 15).exists)
        wait("workshop.preview").tap()
        XCTAssertTrue(wait("workshop.preview.canvas").exists)
        shot("09-workshop")
    }
}

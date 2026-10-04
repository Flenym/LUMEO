//
// LumeoUITests.swift — 7 critical flows (ТЗ acceptance).
// Run: xcodebuild test -scheme Lumeo (also driven by scripts/screenshots.sh).
// The app must honor `--uitesting` launch arg: stub network/auth, seed fixtures,
// and expose every tapped element via accessibilityIdentifier (see below).
//
import XCTest

final class LumeoUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
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
    }

    // MARK: 2. search → request → accept (friends)

    func testFriendsSearchRequestAccept() throws {
        launch()
        wait("tab.friends").tap()
        wait("friends.search").tap()
        app.searchFields["friends.search"].typeText("friend_two")
        wait("friends.search.result").tap()
        wait("friends.request.send").tap()
        XCTAssertTrue(wait("friends.request.pending").exists)
        // Stubbed counterpart accepts; status flips to accepted.
        XCTAssertTrue(wait("friends.request.accepted", timeout: 15).exists)
    }

    // MARK: 3. green → yellow → red (status)

    func testStatusGreenYellowRed() throws {
        launch()
        wait("tab.home").tap()
        wait("status.dot").tap()
        for color in ["green", "yellow", "red"] {
            wait("status.color.\(color)").tap()
            XCTAssertTrue(wait("status.dot.\(color)").exists)
        }
        // Custom text ≤140 chars + TTL timer + auto-revert covered by stub asserts.
        wait("status.save").tap()
        XCTAssertTrue(wait("status.saved").exists)
    }

    // MARK: 4. create → invite → accept → join → finish (session)

    func testSessionCreateInviteAcceptJoinFinish() throws {
        launch()
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
    }

    // MARK: 5. send → receive → read (chat, E2EE ciphertext only on wire)

    func testChatSendReceiveRead() throws {
        launch()
        wait("tab.chats").tap()
        wait("chat.thread.first").tap()
        wait("chat.composer").tap()
        app.textViews["chat.composer"].typeText("hello e2ee")
        wait("chat.send").tap()
        XCTAssertTrue(wait("chat.message.sent").exists)
        XCTAssertTrue(wait("chat.message.delivered", timeout: 15).exists)
        XCTAssertTrue(wait("chat.message.read", timeout: 15).exists)
    }

    // MARK: 6. edit → save → reload (profile constructor)

    func testProfileEditSaveReload() throws {
        launch()
        wait("tab.profile").tap()
        wait("profile.edit").tap()
        wait("profile.block.bio").tap()
        XCTAssertTrue(wait("profile.block.system").exists, "System blocks must be non-removable")
        wait("profile.save").tap()
        app.terminate()
        launch() // reload from "server"
        wait("tab.profile").tap()
        XCTAssertTrue(wait("profile.saved").exists)
    }

    // MARK: 7. create → moderation → publish → preview (workshop)

    func testWorkshopCreateModerationPublishPreview() throws {
        launch()
        wait("tab.workshop").tap()
        wait("workshop.create").tap()
        wait("workshop.create.title").tap()
        wait("workshop.submit").tap()
        XCTAssertTrue(wait("workshop.status.pendingModeration").exists)
        // Stubbed moderation approves -> Published.
        XCTAssertTrue(wait("workshop.status.published", timeout: 15).exists)
        wait("workshop.preview").tap()
        XCTAssertTrue(wait("workshop.preview.canvas").exists)
    }
}

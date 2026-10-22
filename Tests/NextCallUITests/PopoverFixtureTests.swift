import AppKit
import XCTest

/// Drives the real popover with fixed fixture events (`-uiTestFixtures`, debug builds only).
final class PopoverFixtureTests: XCTestCase {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.frdzhv.NextCall.uitest"))

    override func setUp() {
        continueAfterFailure = false
        pasteboard.clearContents()
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFixtures"]
        app.launch()
        return app
    }

    @MainActor
    private func openPopover(_ app: XCUIApplication) {
        let item = app.statusItems.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.click()
        XCTAssertTrue(app.buttons["popover.settings"].waitForExistence(timeout: 5))
    }

    private func openedURL(timeout: TimeInterval = 5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = pasteboard.string(forType: .string), !value.isEmpty { return value }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    @MainActor
    func testHeaderJoinOpensTheImminentMeetingAndClosesThePopover() {
        let app = launch()
        openPopover(app)
        let join = app.buttons["popover.join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        XCTAssertTrue(join.label.contains("Design review"), "label was \(join.label)")
        join.click()
        XCTAssertEqual(openedURL(), "https://meet.google.com/abc-defg-hij")
        XCTAssertTrue(app.buttons["popover.settings"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testArrowKeysSelectRowsAndReturnJoinsTheRunningMeeting() {
        let app = launch()
        openPopover(app)
        XCTAssertTrue(app.buttons["popover.join"].waitForExistence(timeout: 5))
        // The first Down selects the first meeting that has not ended: the running Standup.
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(openedURL(), "https://zoom.us/j/81234567890?pwd=abc123")
    }

    @MainActor
    func testReturnWithoutASelectionJoinsTheHeaderTarget() {
        let app = launch()
        openPopover(app)
        XCTAssertTrue(app.buttons["popover.join"].waitForExistence(timeout: 5))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(openedURL(), "https://meet.google.com/abc-defg-hij")
    }

    @MainActor
    func testStatusItemDescribesTheNextMeeting() {
        let app = launch()
        let item = app.statusItems.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        let predicate = NSPredicate(format: "label CONTAINS %@", "Design review")
        expectation(for: predicate, evaluatedWith: item)
        waitForExpectations(timeout: 10)
    }
}

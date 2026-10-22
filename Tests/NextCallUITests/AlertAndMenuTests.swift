import AppKit
import XCTest

/// Full-screen alert, row context menu and Settings tabs, against the debug fixtures.
final class AlertAndMenuTests: XCTestCase {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.frdzhv.NextCall.uitest"))

    override func setUp() {
        continueAfterFailure = false
        pasteboard.clearContents()
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFixtures"] + extra
        app.launch()
        return app
    }


    private func openedURL(timeout: TimeInterval = 5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = pasteboard.string(forType: .string), !value.isEmpty { return value }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    // MARK: Full-screen alert

    @MainActor
    func testAlertJoinOpensTheMeetingAndClosesTheAlert() {
        let app = launch(["-uiTestShowAlert"])
        let join = app.buttons["alert.join"]
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        XCTAssertTrue(join.label.contains("Design review"), "label was \(join.label)")
        join.click()
        XCTAssertEqual(openedURL(), "https://meet.google.com/abc-defg-hij")
        XCTAssertTrue(join.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testEscapeDismissesTheAlertWithoutJoining() {
        let app = launch(["-uiTestShowAlert"])
        let dismiss = app.buttons["alert.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(dismiss.waitForNonExistence(timeout: 5))
        XCTAssertNil(openedURL(timeout: 1), "dismissing must not join")
    }

    @MainActor
    func testDismissButtonClosesTheAlert() {
        let app = launch(["-uiTestShowAlert"])
        let dismiss = app.buttons["alert.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
        dismiss.click()
        XCTAssertTrue(dismiss.waitForNonExistence(timeout: 5))
    }

    // MARK: Row context menu

    /// A meeting row is one combined accessibility element whose text starts with the title.
    @MainActor
    private func row(_ app: XCUIApplication, titled title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", title, title)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor
    private func menuItem(_ app: XCUIApplication, matching words: [String]) -> XCUIElement {
        let format = words.map { "title CONTAINS '\($0)'" }.joined(separator: " OR ")
        return app.menuItems.matching(NSPredicate(format: format)).firstMatch
    }

    @MainActor
    func testContextMenuHidesAnEvent() {
        let app = launch()
        app.openPopover()
        let row = row(app, titled: "Standup")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.rightClick()
        let hide = menuItem(app, matching: ["Hide this event", "Сховати цю подію"])
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        hide.click()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testContextMenuCopiesTheLink() {
        let app = launch()
        app.openPopover()
        let row = row(app, titled: "Standup")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        NSPasteboard.general.clearContents()
        row.rightClick()
        let copy = menuItem(app, matching: ["Copy link", "Копіювати посилання"])
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        copy.click()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, NSPasteboard.general.string(forType: .string) == nil { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "https://zoom.us/j/81234567890?pwd=abc123")
    }

    @MainActor
    func testEventWithoutALinkHasNoJoinOrCopyItems() {
        let app = launch()
        app.openPopover()
        let row = row(app, titled: "Lunch")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.rightClick()
        XCTAssertTrue(menuItem(app, matching: ["Hide this event", "Сховати цю подію"]).waitForExistence(timeout: 5))
        XCTAssertFalse(menuItem(app, matching: ["Copy link", "Копіювати посилання"]).exists)
    }

    // MARK: Settings

    @MainActor
    func testSettingsHasAllSixTabs() {
        let app = launch()
        app.openPopover()
        app.buttons["popover.settings"].click()
        // Each tab is a toolbar button identified by its SF Symbol name.
        for symbol in ["gearshape", "calendar", "bell", "video", "keyboard", "info.circle"] {
            let tab = app.windows.firstMatch.descendants(matching: .any)[symbol]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "missing tab \(symbol)")
            tab.click()
        }
    }
}

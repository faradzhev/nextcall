import XCTest

final class PopoverSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openPopover() -> XCUIApplication {
        let app = XCUIApplication()
        // Fixtures keep these tests off the real calendar, whose permission prompt would block the UI.
        app.launchArguments += ["-uiTestFixtures"]
        app.launch()
        let item = app.statusItems.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.click()
        return app
    }

    @MainActor
    func testPopoverShowsContentAboveFooter() {
        let app = openPopover()
        let gear = app.buttons["popover.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        let popover = app.popovers.firstMatch
        // Footer alone is ~40pt; any state (list, empty text, permission prompt) must add content above it.
        XCTAssertGreaterThan(popover.frame.height, 80)
    }

    @MainActor
    func testSettingsButtonOpensSettingsWindow() {
        let app = openPopover()
        let gear = app.buttons["popover.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        gear.click()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabGroups.firstMatch.waitForExistence(timeout: 5))
    }
}

import XCTest

extension XCUIApplication {
    /// Opens the popover from the status item. The status item can take a moment to accept its first click
    /// after launch, so retry, but only click again while the popover is still closed (a click toggles it).
    @MainActor
    func openPopover(file: StaticString = #filePath, line: UInt = #line) {
        let item = statusItems.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), "status item missing", file: file, line: line)
        let gear = buttons["popover.settings"]
        for _ in 0..<3 {
            if gear.exists { return }
            item.click()
            if gear.waitForExistence(timeout: 4) { return }
        }
        XCTFail("popover did not open", file: file, line: line)
    }
}

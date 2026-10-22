import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAsAgent() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFixtures"]
        app.launch()
        let running = app.wait(for: .runningBackground, timeout: 10)
            || app.state == .runningForeground
        XCTAssertTrue(running)
    }
}

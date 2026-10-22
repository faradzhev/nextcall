import XCTest

/// The first-launch flow and automated accessibility audits of every surface, against the debug fixtures.
final class OnboardingAndAccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFixtures"] + extra
        app.launch()
        return app
    }


    // MARK: Onboarding

    @MainActor
    func testOnboardingWalksThroughThreeStepsAndOpensThePopover() {
        let app = launch(["-uiTestOnboarding"])
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.back"].isHittable, "no Back on the first step")

        next.click() // welcome -> access
        XCTAssertTrue(app.buttons["onboarding.back"].waitForExistence(timeout: 5))
        next.click() // access -> choose

        let done = app.buttons["onboarding.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertFalse(next.exists)

        app.buttons["onboarding.back"].click()
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Back returns to the previous step")
        next.click()

        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.click()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        // Done points at the menu bar item by opening its popover.
        XCTAssertTrue(app.buttons["popover.settings"].waitForExistence(timeout: 5))
    }

    // MARK: Accessibility

    @MainActor
    private func audit(_ app: XCUIApplication, _ surface: String) throws {
        var issues: [String] = []
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .parentChild]) { issue in
            // The audit also walks things we do not own: system chrome (Touch Bar, menu bar) and the plain
            // layout groups SwiftUI wraps around a window, which VoiceOver skips.
            let type = issue.element?.elementType
            if issue.element == nil || type == .touchBar || type == .menuBar || type == .menuBarItem || type == .group { return true }
            // Items above the screen's top edge belong to the system menu bar (for example "Emoji & Symbols").
            if let frame = issue.element?.frame, frame.minY < 1 { return true }
            issues.append("\(issue.auditType): \(issue.compactDescription) [\(issue.element?.debugDescription.prefix(160) ?? "")]")
            return true // keep collecting so one failure lists every problem
        }
        XCTAssertTrue(issues.isEmpty, "\(surface):\n" + issues.joined(separator: "\n"))
    }

    @MainActor
    func testPopoverPassesTheAccessibilityAudit() throws {
        let app = launch()
        app.openPopover()
        try audit(app, "popover")
    }

    @MainActor
    func testSettingsWindowPassesTheAccessibilityAudit() throws {
        let app = launch()
        app.openPopover()
        app.buttons["popover.settings"].click()
        for symbol in ["gearshape", "calendar", "bell", "video", "keyboard", "info.circle"] {
            let tab = app.windows.firstMatch.descendants(matching: .any)[symbol]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.click()
            try audit(app, "settings tab \(symbol)")
        }
    }

    @MainActor
    func testAlertPassesTheAccessibilityAudit() throws {
        let app = launch(["-uiTestShowAlert"])
        XCTAssertTrue(app.buttons["alert.join"].waitForExistence(timeout: 10))
        try audit(app, "alert")
    }

    @MainActor
    func testOnboardingPassesTheAccessibilityAudit() throws {
        let app = launch(["-uiTestOnboarding"])
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        try audit(app, "onboarding step 1")
        next.click()
        try audit(app, "onboarding step 2")
        next.click()
        try audit(app, "onboarding step 3")
    }

    @MainActor
    func testEveryButtonHasAnAccessibleName() {
        let app = launch(["-uiTestShowAlert"])
        app.openPopover()
        let unnamed = app.buttons.allElementsBoundByIndex.filter { $0.label.isEmpty && $0.title.isEmpty }
        XCTAssertTrue(unnamed.isEmpty, "unnamed buttons: \(unnamed.map { $0.debugDescription })")
    }
}

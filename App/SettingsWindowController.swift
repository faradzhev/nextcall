import AppKit
import SwiftUI

/// Hosts the SwiftUI settings tabs in a plain window. The SwiftUI `Settings` scene cannot be opened
/// reliably from an agent app's status item, so the window is owned here instead.
@MainActor
final class SettingsWindowController {
    private let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView().environment(appState))
        let window = NSWindow(contentViewController: hosting)
        window.title = String(localized: "Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

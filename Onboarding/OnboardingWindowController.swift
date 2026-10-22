import AppKit
import SwiftUI

/// Hosts the onboarding flow in its own window. Closing it any way counts as finished, so it never nags.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private let onFinish: () -> Void
    private var window: NSWindow?

    init(appState: AppState, onFinish: @escaping () -> Void) {
        self.appState = appState
        self.onFinish = onFinish
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: OnboardingView { [weak self] in self?.finish() }.environment(appState)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = String(localized: "Welcome")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        window?.close()
        onFinish()
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: OnboardingKey.completed)
    }
}

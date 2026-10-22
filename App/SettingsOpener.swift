import AppKit

@MainActor
enum SettingsOpener {
    /// Opens the SwiftUI `Settings` scene; an agent app must activate itself first to bring it to front.
    static func open() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

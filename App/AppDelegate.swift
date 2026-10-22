import AppKit
import NextCallCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?
    private lazy var settingsWindow = SettingsWindowController(appState: appState)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(appState: appState) { [weak self] in
            self?.settingsWindow.show()
        }
        appState.start()
        Log.app.info("NextCall launched")
    }
}

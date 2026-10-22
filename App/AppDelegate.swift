import AppKit
import NextCallCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(appState: appState) {
            SettingsOpener.open()
        }
        appState.start()
        Log.app.info("NextCall launched")
    }
}

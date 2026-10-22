import AppKit
import KeyboardShortcuts
import NextCallCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState: AppState = {
        #if DEBUG
        if UITestSupport.isActive { return UITestSupport.makeAppState() }
        #endif
        return AppState()
    }()
    private var statusItemController: StatusItemController?
    private lazy var settingsWindow = SettingsWindowController(appState: appState)
    private var notificationDelegate: NotificationDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(appState: appState) { [weak self] in
            self?.settingsWindow.show()
        }
        registerHotkeys()
        registerNotificationDelegate()
        appState.start()
        #if DEBUG
        UITestSupport.runLaunchHooks(appState)
        #endif
        Log.app.info("NextCall launched")
    }

    /// Carbon-based global hotkeys: sandbox-safe, and they fire on the main thread.
    private func registerHotkeys() {
        KeyboardShortcuts.onKeyUp(for: .openPopover) { [weak self] in
            Task { @MainActor in self?.statusItemController?.showPopover() }
        }
        KeyboardShortcuts.onKeyUp(for: .joinNext) { [weak self] in
            Task { @MainActor in self?.appState.joinNext() }
        }
        KeyboardShortcuts.onKeyUp(for: .dismissAlert) { [weak self] in
            Task { @MainActor in self?.appState.dismissFullScreenAlert() }
        }
    }

    private func registerNotificationDelegate() {
        let state = appState
        let delegate = NotificationDelegate { response in
            Task { @MainActor in state.handleNotification(response) }
        }
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }
}

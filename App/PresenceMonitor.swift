import AppKit

/// Tells whether the user is away from the Mac: screen locked, display asleep or the login session in the background.
/// Notification-driven, never polling.
@MainActor
final class PresenceMonitor {
    private(set) var isAway = false
    /// Called on the main actor when `isAway` changes.
    var onChange: (@MainActor (Bool) -> Void)?

    private var locked = false
    private var displayAsleep = false
    private var sessionInactive = false
    /// Observers live as long as the app, so they are never removed.
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked") { $0.locked = true }
        observe(distributed, "com.apple.screenIsUnlocked") { $0.locked = false }
        observe(workspace, NSWorkspace.screensDidSleepNotification.rawValue) { $0.displayAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue) { $0.displayAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification.rawValue) { $0.sessionInactive = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification.rawValue) { $0.sessionInactive = false }
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ update: @escaping @MainActor (PresenceMonitor) -> Void) {
        _ = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                update(self)
                let away = self.locked || self.displayAsleep || self.sessionInactive
                guard away != self.isAway else { return }
                self.isAway = away
                self.onChange?(away)
            }
        }
    }
}

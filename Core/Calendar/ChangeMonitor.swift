import AppKit
import EventKit

public enum ChangeReason: Sendable, Equatable {
    case eventStore
    case wake
    case dayChanged
    case timeZone
    case clock
}

/// Turns the system notifications that can invalidate the event list into one stream.
/// Notification-driven, never polling.
public struct ChangeMonitor: Sendable {
    private let center: NotificationCenter
    private let workspaceCenter: NotificationCenter

    public init(center: NotificationCenter, workspaceCenter: NotificationCenter) {
        self.center = center
        self.workspaceCenter = workspaceCenter
    }

    @MainActor
    public static func live() -> ChangeMonitor {
        ChangeMonitor(center: .default, workspaceCenter: NSWorkspace.shared.notificationCenter)
    }

    public func changes() -> AsyncStream<ChangeReason> {
        let center = center
        let workspaceCenter = workspaceCenter
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observers = ObserverBag()
            let sources: [(NotificationCenter, Notification.Name, ChangeReason)] = [
                (center, .EKEventStoreChanged, .eventStore),
                (workspaceCenter, NSWorkspace.didWakeNotification, .wake),
                (center, .NSCalendarDayChanged, .dayChanged),
                (center, NSNotification.Name.NSSystemTimeZoneDidChange, .timeZone),
                (center, NSNotification.Name.NSSystemClockDidChange, .clock),
            ]
            for (source, name, reason) in sources {
                let token = source.addObserver(forName: name, object: nil, queue: nil) { _ in
                    continuation.yield(reason)
                }
                observers.add(token, from: source)
            }
            continuation.onTermination = { _ in observers.removeAll() }
        }
    }
}

private final class ObserverBag: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(token: NSObjectProtocol, center: NotificationCenter)] = []

    func add(_ token: NSObjectProtocol, from center: NotificationCenter) {
        lock.withLock { entries.append((token, center)) }
    }

    func removeAll() {
        let removed = lock.withLock {
            defer { entries.removeAll() }
            return entries
        }
        for entry in removed { entry.center.removeObserver(entry.token) }
    }
}

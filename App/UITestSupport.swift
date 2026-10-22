#if DEBUG
import AppKit
import Foundation
import NextCallCore

/// Debug-only fixtures so UI tests can drive the real popover and status item without touching the
/// user's calendar, default browser or login items. Active only with the `-uiTestFixtures` launch argument.
enum UITestSupport {
    static let pasteboardName = NSPasteboard.Name("com.frdzhv.NextCall.uitest")

    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFixtures") }

    @MainActor
    static func makeAppState() -> AppState {
        let suite = "com.frdzhv.NextCall.uitest"
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
        settings.update { $0.menuBarMode = .titleAndCountdown }
        let service = CalendarService(dataSource: FixtureDataSource(), changes: { AsyncStream { $0.finish() } })
        return AppState(
            settings: settings,
            service: service,
            launcher: MeetingLauncher(workspace: PasteboardWorkspace()),
            launchAtLogin: LaunchAtLogin(service: InMemoryLoginService())
        )
    }
}

/// "Opens" a URL by writing it to a named pasteboard the UI test can read.
@MainActor
private struct PasteboardWorkspace: WorkspaceControlling {
    func applicationURL(toOpen url: URL) -> URL? { nil }
    func applicationURL(forBundleIdentifier bundleID: String) -> URL? { nil }

    func open(_ url: URL, withApplicationAt applicationURL: URL?) async throws {
        let pasteboard = NSPasteboard(name: UITestSupport.pasteboardName)
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
    }
}

private final class InMemoryLoginService: LoginItemService, @unchecked Sendable {
    private let lock = NSLock()
    private var current = LoginItemStatus.notRegistered
    var status: LoginItemStatus { lock.withLock { current } }
    func register() throws { lock.withLock { current = .enabled } }
    func unregister() throws { lock.withLock { current = .notRegistered } }
    func openSystemSettings() {}
}

/// A small, fixed day relative to the launch time: one finished, one running, one about to start.
private struct FixtureDataSource: CalendarDataSource {
    private let calendarRef = CalendarRef(
        id: "ui-cal",
        title: "Work",
        color: CalendarColor(red: 0.2, green: 0.5, blue: 0.9),
        source: CalendarSource(id: "ui-src", title: "iCloud", kind: .calDAV)
    )

    func authorization() async -> CalendarAuthorization { .granted }
    func requestAccess() async -> CalendarAuthorization { .granted }
    func calendars() async -> [CalendarRef] { [calendarRef] }

    func events(from start: Date, to end: Date, excludingCalendarIDs: Set<String>) async -> [RawEvent] {
        let now = Date()
        func event(_ id: String, _ title: String, startOffset: TimeInterval, minutes: Double, location: String? = nil, attendees: Int = 4) -> RawEvent {
            let begin = now.addingTimeInterval(startOffset)
            return RawEvent(
                id: id, title: title, start: begin, end: begin.addingTimeInterval(minutes * 60),
                calendar: calendarRef, location: location, attendeeCount: attendees, otherAttendeeCount: max(attendees - 1, 0),
                myStatus: .accepted
            )
        }
        return [
            event("past", "Earlier sync", startOffset: -3 * 3600, minutes: 30, location: "https://meet.google.com/old-oldd-old"),
            event("running", "Standup", startOffset: -10 * 60, minutes: 30, location: "https://zoom.us/j/81234567890?pwd=abc123"),
            event("soon", "Design review", startOffset: 4 * 60, minutes: 45, location: "https://meet.google.com/abc-defg-hij"),
            event("lunch", "Lunch", startOffset: 2 * 3600, minutes: 60, attendees: 0),
            event("tomorrow", "Retro", startOffset: 20 * 3600, minutes: 60, location: "https://teams.microsoft.com/meet/3123456789012?p=AbCdEf"),
        ]
    }
}
#endif

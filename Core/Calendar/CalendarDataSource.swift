import Foundation

/// Seam over EventKit so the service and everything above it run headless in tests.
public protocol CalendarDataSource: Sendable {
    func authorization() async -> CalendarAuthorization
    /// Asks the system for full calendar access; returns the resulting state.
    func requestAccess() async -> CalendarAuthorization
    func calendars() async -> [CalendarRef]
    func events(from start: Date, to end: Date, excludingCalendarIDs: Set<String>) async -> [RawEvent]
}

public enum SystemSettingsLink {
    public static let calendarPrivacy = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
    )!
}

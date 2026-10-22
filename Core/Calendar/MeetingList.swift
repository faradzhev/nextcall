import Foundation

public enum PastEventsMode: String, Codable, CaseIterable, Sendable {
    case hidden
    case dimmed
}

public struct MeetingListOptions: Equatable, Sendable {
    public var showAllDay: Bool
    public var hideDeclined: Bool
    public var pastEvents: PastEventsMode

    public init(showAllDay: Bool, hideDeclined: Bool, pastEvents: PastEventsMode) {
        self.showAllDay = showAllDay
        self.hideDeclined = hideDeclined
        self.pastEvents = pastEvents
    }
}

public struct DaySection: Identifiable, Hashable, Sendable {
    /// Start of the day this section covers.
    public let day: Date
    public let meetings: [Meeting]
    public var id: Date { day }
}

public enum MeetingList {
    /// Applies display options and groups meetings by day. Pure, so it is tested without a UI.
    /// A meeting that began before today but is still running is listed under today.
    public static func sections(
        _ meetings: [Meeting],
        options: MeetingListOptions,
        now: Date,
        calendar: Calendar
    ) -> [DaySection] {
        let startOfToday = calendar.startOfDay(for: now)

        let visible = meetings.filter { meeting in
            if meeting.isAllDay && !options.showAllDay { return false }
            if options.hideDeclined && meeting.myStatus == .declined { return false }
            if options.pastEvents == .hidden && meeting.isPast(at: now) { return false }
            return true
        }

        let grouped = Dictionary(grouping: visible) { calendar.startOfDay(for: max($0.start, startOfToday)) }
        return grouped.keys.sorted().map { day in
            DaySection(day: day, meetings: grouped[day, default: []].sorted(by: displayOrder))
        }
    }

    private static func displayOrder(_ a: Meeting, _ b: Meeting) -> Bool {
        if a.isAllDay != b.isAllDay { return a.isAllDay }
        return CalendarService.chronological(a, b)
    }
}

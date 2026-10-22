import Foundation
@testable import NextCallCore

enum TestCalendars {
    static func gregorian(_ identifier: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    static let utc = gregorian("UTC")
    static let newYork = gregorian("America/New_York")
}

func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, calendar: Calendar = TestCalendars.utc) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func makeCalendarRef(id: String = "cal-1", title: String = "Work", source: String = "iCloud", sourceID: String = "src-1") -> CalendarRef {
    CalendarRef(
        id: id,
        title: title,
        color: .gray,
        source: CalendarSource(id: sourceID, title: source, kind: .calDAV)
    )
}

func makeEvent(
    _ id: String = UUID().uuidString,
    title: String = "Standup",
    start: Date,
    minutes: Int = 30,
    allDay: Bool = false,
    canceled: Bool = false,
    status: ParticipantStatus = .accepted,
    attendees: Int = 3,
    availability: EventAvailability = .busy,
    calendar: CalendarRef = makeCalendarRef()
) -> RawEvent {
    RawEvent(
        id: id,
        title: title,
        start: start,
        end: start.addingTimeInterval(Double(minutes) * 60),
        isAllDay: allDay,
        isCanceled: canceled,
        calendar: calendar,
        attendeeCount: attendees,
        otherAttendeeCount: max(attendees - 1, 0),
        myStatus: status,
        availability: availability
    )
}

func makeMeeting(
    _ id: String = UUID().uuidString,
    title: String = "Standup",
    start: Date,
    minutes: Int = 30,
    allDay: Bool = false,
    status: ParticipantStatus = .accepted
) -> Meeting {
    Meeting(raw: makeEvent(id, title: title, start: start, minutes: minutes, allDay: allDay, status: status))
}

actor FakeDataSource: CalendarDataSource {
    var status: CalendarAuthorization
    var calendarList: [CalendarRef]
    var eventList: [RawEvent]
    private(set) var eventRequests: [(start: Date, end: Date, excluded: Set<String>)] = []
    private(set) var accessRequests = 0
    var statusAfterRequest: CalendarAuthorization = .granted

    init(status: CalendarAuthorization = .granted, calendars: [CalendarRef] = [], events: [RawEvent] = []) {
        self.status = status
        calendarList = calendars
        eventList = events
    }

    func setStatus(_ new: CalendarAuthorization) { status = new }
    func setEvents(_ events: [RawEvent]) { eventList = events }

    func authorization() async -> CalendarAuthorization { status }

    func requestAccess() async -> CalendarAuthorization {
        accessRequests += 1
        status = statusAfterRequest
        return status
    }

    func calendars() async -> [CalendarRef] { calendarList }

    func events(from start: Date, to end: Date, excludingCalendarIDs: Set<String>) async -> [RawEvent] {
        eventRequests.append((start, end, excludingCalendarIDs))
        return eventList.filter { !excludingCalendarIDs.contains($0.calendar.id) }
    }
}

actor Collector<Element: Sendable> {
    private(set) var items: [Element] = []
    func add(_ item: Element) { items.append(item) }
}

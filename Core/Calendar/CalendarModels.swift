import Foundation

public struct CalendarColor: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let gray = CalendarColor(red: 0.56, green: 0.56, blue: 0.58)
}

public enum CalendarSourceKind: String, Hashable, Sendable {
    case local, exchange, calDAV, mobileMe, subscribed, birthdays
}

public struct CalendarSource: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let kind: CalendarSourceKind

    public init(id: String, title: String, kind: CalendarSourceKind) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}

public struct CalendarRef: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let color: CalendarColor
    public let source: CalendarSource

    public init(id: String, title: String, color: CalendarColor, source: CalendarSource) {
        self.id = id
        self.title = title
        self.color = color
        self.source = source
    }
}

public enum CalendarAuthorization: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
    case restricted
}

public enum ParticipantStatus: Sendable, Equatable {
    case unknown, pending, accepted, declined, tentative
}

public enum EventAvailability: Sendable, Equatable {
    case busy, free, tentative, unavailable
}

/// One event occurrence as read from the calendar store, before link detection.
/// Never leaves the device and is never persisted.
public struct RawEvent: Sendable, Equatable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let isCanceled: Bool
    public let calendar: CalendarRef
    public let url: URL?
    public let location: String?
    public let notes: String?
    public let attendeeCount: Int
    public let otherAttendeeCount: Int
    /// Email addresses of the other attendees, for "Email attendees".
    public let attendeeEmails: [String]
    public let myStatus: ParticipantStatus
    public let availability: EventAvailability

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        isCanceled: Bool = false,
        calendar: CalendarRef,
        url: URL? = nil,
        location: String? = nil,
        notes: String? = nil,
        attendeeCount: Int = 0,
        otherAttendeeCount: Int = 0,
        attendeeEmails: [String] = [],
        myStatus: ParticipantStatus = .unknown,
        availability: EventAvailability = .busy
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.isCanceled = isCanceled
        self.calendar = calendar
        self.url = url
        self.location = location
        self.notes = notes
        self.attendeeCount = attendeeCount
        self.otherAttendeeCount = otherAttendeeCount
        self.attendeeEmails = attendeeEmails
        self.myStatus = myStatus
        self.availability = availability
    }
}

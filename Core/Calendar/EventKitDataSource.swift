import AppKit
import EventKit

/// EventKit-backed data source. `EKEventStore` is not `Sendable`, so it is confined to this class:
/// it is only touched inside the methods below, and `EKEvent` objects are mapped to value types
/// before they leave. That confinement is what makes `@unchecked Sendable` sound here.
public final class EventKitDataSource: CalendarDataSource, @unchecked Sendable {
    private let store = EKEventStore()

    public init() {}

    public func authorization() async -> CalendarAuthorization {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAccess() async -> CalendarAuthorization {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            Log.calendar.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
        }
        return Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    public func calendars() async -> [CalendarRef] {
        store.calendars(for: .event).map(Self.map)
    }

    public func events(from start: Date, to end: Date, excludingCalendarIDs: Set<String>) async -> [RawEvent] {
        let included = store.calendars(for: .event).filter { !excludingCalendarIDs.contains($0.calendarIdentifier) }
        guard !included.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: included)
        return store.events(matching: predicate).compactMap(Self.map)
    }

    // MARK: Mapping

    static func map(_ status: EKAuthorizationStatus) -> CalendarAuthorization {
        switch status {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        default: .denied // .denied, .writeOnly (not enough to read events)
        }
    }

    static func map(_ calendar: EKCalendar) -> CalendarRef {
        CalendarRef(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: rgb(calendar.cgColor),
            source: CalendarSource(
                id: calendar.source?.sourceIdentifier ?? "unknown",
                title: calendar.source?.title ?? "",
                kind: calendar.source.map { map($0.sourceType) } ?? .local
            )
        )
    }

    static func map(_ type: EKSourceType) -> CalendarSourceKind {
        switch type {
        case .local: .local
        case .exchange: .exchange
        case .calDAV: .calDAV
        case .mobileMe: .mobileMe
        case .subscribed: .subscribed
        case .birthdays: .birthdays
        @unknown default: .local
        }
    }

    /// `nil` for an event without a calendar, which EventKit should never hand out for a fetched event.
    static func map(_ event: EKEvent) -> RawEvent? {
        guard let calendar = event.calendar else { return nil }
        let attendees = event.attendees ?? []
        let me = attendees.first(where: \.isCurrentUser)
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        let start = event.startDate ?? .distantPast
        return RawEvent(
            id: "\(identifier)|\(start.timeIntervalSinceReferenceDate)",
            title: event.title ?? "",
            start: start,
            end: event.endDate ?? start,
            isAllDay: event.isAllDay,
            isCanceled: event.status == .canceled,
            calendar: map(calendar),
            url: event.url,
            location: event.location,
            notes: event.notes,
            attendeeCount: attendees.count,
            otherAttendeeCount: attendees.filter { !$0.isCurrentUser }.count,
            myStatus: me.map { map($0.participantStatus) } ?? .unknown,
            availability: map(event.availability)
        )
    }

    static func map(_ status: EKParticipantStatus) -> ParticipantStatus {
        switch status {
        case .accepted: .accepted
        case .declined: .declined
        case .tentative: .tentative
        case .pending, .delegated, .inProcess: .pending
        default: .unknown
        }
    }

    static func map(_ availability: EKEventAvailability) -> EventAvailability {
        switch availability {
        case .free: .free
        case .tentative: .tentative
        case .unavailable: .unavailable
        default: .busy // .busy and .notSupported: not known to be free
        }
    }

    private static func rgb(_ cgColor: CGColor?) -> CalendarColor {
        guard let cgColor, let color = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) else { return .gray }
        return CalendarColor(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
}

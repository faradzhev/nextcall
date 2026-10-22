import Foundation

public enum Provider: String, CaseIterable, Hashable, Sendable {
    case zoom, googleMeet, teams, webex, slackHuddle, faceTime
    case jitsi, whereby, goTo, chime, ringCentral, blueJeans, discord, skype
    case around, zoho, livestorm, gather, pop, tuple
}

public struct MeetingLink: Hashable, Sendable {
    public let provider: Provider
    /// Cleaned, unwrapped URL.
    public let url: URL
    /// Native-app URL (e.g. `zoommtg://`) where the provider has one.
    public let nativeURL: URL?

    public init(provider: Provider, url: URL, nativeURL: URL?) {
        self.provider = provider
        self.url = url
        self.nativeURL = nativeURL
    }
}

public struct Meeting: Identifiable, Hashable, Sendable {
    /// `eventIdentifier` plus occurrence start, so recurring occurrences stay distinct.
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendar: CalendarRef
    public let link: MeetingLink?
    public let attendeeCount: Int
    public let otherAttendeeCount: Int
    public let myStatus: ParticipantStatus
    public let availability: EventAvailability

    public init(raw: RawEvent, link: MeetingLink? = nil) {
        id = raw.id
        title = raw.title
        start = raw.start
        end = max(raw.end, raw.start)
        isAllDay = raw.isAllDay
        calendar = raw.calendar
        self.link = link
        attendeeCount = raw.attendeeCount
        otherAttendeeCount = raw.otherAttendeeCount
        myStatus = raw.myStatus
        availability = raw.availability
    }

    public func isPast(at now: Date) -> Bool { end <= now }

    public func isOngoing(at now: Date) -> Bool { !isAllDay && start <= now && now < end }
}

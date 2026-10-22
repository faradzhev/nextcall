import Foundation

public enum Provider: String, CaseIterable, Hashable, Sendable {
    case zoom, googleMeet, teams, webex, slackHuddle, faceTime
    case jitsi, whereby, goTo, chime, ringCentral, blueJeans, discord, skype
    case around, zoho, livestorm, gather, pop, tuple, dialpad

    /// Product names, so they are not localized.
    public var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Microsoft Teams"
        case .webex: "Webex"
        case .slackHuddle: "Slack Huddle"
        case .faceTime: "FaceTime"
        case .jitsi: "Jitsi Meet"
        case .whereby: "Whereby"
        case .goTo: "GoTo"
        case .chime: "Amazon Chime"
        case .ringCentral: "RingCentral"
        case .blueJeans: "BlueJeans"
        case .discord: "Discord"
        case .skype: "Skype"
        case .around: "Around"
        case .zoho: "Zoho Meeting"
        case .livestorm: "Livestorm"
        case .gather: "Gather"
        case .pop: "Pop"
        case .tuple: "Tuple"
        case .dialpad: "Dialpad"
        }
    }
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
    public let attendeeEmails: [String]
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
        attendeeEmails = raw.attendeeEmails
        myStatus = raw.myStatus
        availability = raw.availability
    }

    /// The EventKit identifier without the occurrence suffix (see `id`).
    public var eventIdentifier: String {
        guard let separator = id.lastIndex(of: "|") else { return id }
        return String(id[..<separator])
    }

    public func isPast(at now: Date) -> Bool { end <= now }

    public func isOngoing(at now: Date) -> Bool { !isAllDay && start <= now && now < end }
}

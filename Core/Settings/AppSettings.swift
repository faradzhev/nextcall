import Foundation

/// The one Codable settings blob. Decoding tolerates missing keys so older blobs keep working.
public struct AppSettings: Codable, Equatable, Sendable {
    public var daysAhead: Int
    public var showAllDay: Bool
    public var hideDeclined: Bool
    public var pastEvents: PastEventsMode
    /// Calendars the user switched off. Storing the off-set means new calendars default to on.
    public var disabledCalendarIDs: Set<String>
    public var ignoreKeywords: [String]
    public var ignoreSoloEvents: Bool
    public var ignoreFreeEvents: Bool
    public var ignoredEvents: IgnoredEventsMode

    public init(
        daysAhead: Int = 2,
        showAllDay: Bool = false,
        hideDeclined: Bool = true,
        pastEvents: PastEventsMode = .dimmed,
        disabledCalendarIDs: Set<String> = [],
        ignoreKeywords: [String] = EventFilterRules.defaultIgnoreKeywords,
        ignoreSoloEvents: Bool = true,
        ignoreFreeEvents: Bool = true,
        ignoredEvents: IgnoredEventsMode = .dimmed
    ) {
        self.daysAhead = daysAhead
        self.showAllDay = showAllDay
        self.hideDeclined = hideDeclined
        self.pastEvents = pastEvents
        self.disabledCalendarIDs = disabledCalendarIDs
        self.ignoreKeywords = ignoreKeywords
        self.ignoreSoloEvents = ignoreSoloEvents
        self.ignoreFreeEvents = ignoreFreeEvents
        self.ignoredEvents = ignoredEvents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        daysAhead = try c.decodeIfPresent(Int.self, forKey: .daysAhead) ?? defaults.daysAhead
        showAllDay = try c.decodeIfPresent(Bool.self, forKey: .showAllDay) ?? defaults.showAllDay
        hideDeclined = try c.decodeIfPresent(Bool.self, forKey: .hideDeclined) ?? defaults.hideDeclined
        pastEvents = try c.decodeIfPresent(PastEventsMode.self, forKey: .pastEvents) ?? defaults.pastEvents
        disabledCalendarIDs = try c.decodeIfPresent(Set<String>.self, forKey: .disabledCalendarIDs) ?? defaults.disabledCalendarIDs
        ignoreKeywords = try c.decodeIfPresent([String].self, forKey: .ignoreKeywords) ?? defaults.ignoreKeywords
        ignoreSoloEvents = try c.decodeIfPresent(Bool.self, forKey: .ignoreSoloEvents) ?? defaults.ignoreSoloEvents
        ignoreFreeEvents = try c.decodeIfPresent(Bool.self, forKey: .ignoreFreeEvents) ?? defaults.ignoreFreeEvents
        ignoredEvents = try c.decodeIfPresent(IgnoredEventsMode.self, forKey: .ignoredEvents) ?? defaults.ignoredEvents
    }

    public var listOptions: MeetingListOptions {
        MeetingListOptions(showAllDay: showAllDay, hideDeclined: hideDeclined, pastEvents: pastEvents, ignoredEvents: ignoredEvents)
    }

    public var filterRules: EventFilterRules {
        EventFilterRules(ignoreKeywords: ignoreKeywords, ignoreSoloEvents: ignoreSoloEvents, ignoreFreeEvents: ignoreFreeEvents)
    }
}

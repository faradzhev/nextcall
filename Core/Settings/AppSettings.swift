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
    public var menuBarMode: MenuBarMode
    public var menuBarTitleLength: Int
    /// Open mode per provider, keyed by `Provider.rawValue`; missing means `.app`.
    public var providerOpenModes: [String: OpenMode]
    /// Bundle ID of the preferred browser; nil is the system default.
    public var browserBundleID: String?

    public init(
        daysAhead: Int = 2,
        showAllDay: Bool = false,
        hideDeclined: Bool = true,
        pastEvents: PastEventsMode = .dimmed,
        disabledCalendarIDs: Set<String> = [],
        ignoreKeywords: [String] = EventFilterRules.defaultIgnoreKeywords,
        ignoreSoloEvents: Bool = true,
        ignoreFreeEvents: Bool = true,
        ignoredEvents: IgnoredEventsMode = .dimmed,
        menuBarMode: MenuBarMode = .countdown,
        menuBarTitleLength: Int = 20,
        providerOpenModes: [String: OpenMode] = [:],
        browserBundleID: String? = nil
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
        self.menuBarMode = menuBarMode
        self.menuBarTitleLength = menuBarTitleLength
        self.providerOpenModes = providerOpenModes
        self.browserBundleID = browserBundleID
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
        menuBarMode = try c.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode) ?? defaults.menuBarMode
        menuBarTitleLength = try c.decodeIfPresent(Int.self, forKey: .menuBarTitleLength) ?? defaults.menuBarTitleLength
        providerOpenModes = try c.decodeIfPresent([String: OpenMode].self, forKey: .providerOpenModes) ?? defaults.providerOpenModes
        browserBundleID = try c.decodeIfPresent(String.self, forKey: .browserBundleID)
    }

    public var listOptions: MeetingListOptions {
        MeetingListOptions(showAllDay: showAllDay, hideDeclined: hideDeclined, pastEvents: pastEvents, ignoredEvents: ignoredEvents)
    }

    public static let titleLengthRange = 5...40

    public var launchPreferences: LaunchPreferences {
        var modes: [Provider: OpenMode] = [:]
        for (key, mode) in providerOpenModes {
            if let provider = Provider(rawValue: key) { modes[provider] = mode }
        }
        return LaunchPreferences(modes: modes, browserBundleID: browserBundleID)
    }

    public var filterRules: EventFilterRules {
        EventFilterRules(ignoreKeywords: ignoreKeywords, ignoreSoloEvents: ignoreSoloEvents, ignoreFreeEvents: ignoreFreeEvents)
    }
}

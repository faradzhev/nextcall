import Foundation

/// Calendars of one account (iCloud, Google, Exchange, ...), for the grouped toggles in Settings.
public struct CalendarGroup: Identifiable, Hashable, Sendable {
    public let source: CalendarSource
    public let calendars: [CalendarRef]
    public var id: String { source.id }

    public static func groups(from calendars: [CalendarRef]) -> [CalendarGroup] {
        Dictionary(grouping: calendars, by: \.source)
            .map { source, members in
                CalendarGroup(
                    source: source,
                    calendars: members.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                )
            }
            .sorted { $0.source.title.localizedCaseInsensitiveCompare($1.source.title) == .orderedAscending }
    }
}

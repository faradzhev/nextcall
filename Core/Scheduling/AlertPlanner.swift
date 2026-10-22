import Foundation

public struct AlertRules: Sendable, Equatable {
    public var enabled: Bool
    public var leadMinutes: Int
    public var sound: Bool
    public var onlyWithLinks: Bool

    public init(enabled: Bool = true, leadMinutes: Int = 1, sound: Bool = true, onlyWithLinks: Bool = false) {
        self.enabled = enabled
        self.leadMinutes = leadMinutes
        self.sound = sound
        self.onlyWithLinks = onlyWithLinks
    }
}

public struct PlannedAlert: Sendable, Equatable, Identifiable {
    /// Stable for one meeting occurrence and set of rules, so a changed meeting or rule produces a new ID.
    public let id: String
    public let meeting: Meeting
    public let fireDate: Date
    /// The lead time has already passed but the meeting has not started: fire right away.
    public let isLate: Bool
}

/// Pure planning of which meetings get a reminder and when (FR-09).
public enum AlertPlanner {
    public static let idPrefix = "nc."
    public static let horizon: TimeInterval = 36 * 3600
    public static let maxAlerts = 48

    /// Meetings that may trigger a notification or full-screen alert (FR-10, FR-16): timed, not declined,
    /// not a personal block, and, if asked, with a link.
    public static func isEligible(_ meeting: Meeting, filter: EventFilter?, onlyWithLinks: Bool) -> Bool {
        guard !meeting.isAllDay, meeting.myStatus != .declined else { return false }
        if filter?.isPersonal(meeting) == true { return false }
        if onlyWithLinks && meeting.link == nil { return false }
        return true
    }

    public static func plan(
        meetings: [Meeting],
        filter: EventFilter?,
        rules: AlertRules,
        now: Date
    ) -> [PlannedAlert] {
        guard rules.enabled else { return [] }
        let lead = TimeInterval(rules.leadMinutes) * 60
        return meetings
            .filter { $0.start > now && $0.start.timeIntervalSince(now) <= horizon }
            .filter { isEligible($0, filter: filter, onlyWithLinks: rules.onlyWithLinks) }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
            .prefix(maxAlerts)
            .map { meeting in
                let fire = meeting.start.addingTimeInterval(-lead)
                let late = fire <= now
                return PlannedAlert(
                    id: "\(idPrefix)\(meeting.id).\(rules.leadMinutes).\(rules.sound ? 1 : 0)",
                    meeting: meeting,
                    fireDate: late ? now.addingTimeInterval(1) : fire,
                    isLate: late
                )
            }
    }
}

/// Decides when the full-screen alert is due: once per meeting, at its start, shortly after
/// a missed tick (wake, launch) but never for a meeting that began long ago.
public struct FullScreenAlertTracker: Sendable {
    public static let grace: TimeInterval = 120

    private var shown: Set<String> = []

    public init() {}

    public mutating func due(snapshot: TimelineSnapshot, filter: EventFilter?, onlyWithLinks: Bool) -> [Meeting] {
        let due = snapshot.ongoing.filter { meeting in
            snapshot.now.timeIntervalSince(meeting.start) <= Self.grace
                && !shown.contains(meeting.id)
                && AlertPlanner.isEligible(meeting, filter: filter, onlyWithLinks: onlyWithLinks)
        }
        shown.formUnion(due.map(\.id))
        if shown.count > 500 {
            let live = Set((snapshot.ongoing + snapshot.upcoming).map(\.id))
            shown.formIntersection(live)
        }
        return due
    }
}

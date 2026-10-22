import Foundation

public struct TimelineConfig: Sendable, Equatable {
    /// Within this many seconds of the start, the next meeting takes over the menu bar and gets the accent colour.
    public var imminentWindow: TimeInterval
    /// Meetings further away than this are not shown as a countdown and are not the "join next" target.
    public var countdownHorizon: TimeInterval

    public init(imminentWindow: TimeInterval = 5 * 60, countdownHorizon: TimeInterval = 8 * 3600) {
        self.imminentWindow = imminentWindow
        self.countdownHorizon = countdownHorizon
    }
}

public enum MenuBarStatus: Sendable, Equatable {
    case idle
    case upcoming(Meeting, secondsUntilStart: TimeInterval)
    case ongoing(Meeting)
}

public struct TimelineSnapshot: Sendable, Equatable {
    public let now: Date
    /// Running meetings, earliest start first.
    public let ongoing: [Meeting]
    /// Meetings not started yet, soonest first.
    public let upcoming: [Meeting]
    public let status: MenuBarStatus
    /// The meeting the Join button and the "join next" action open, if it has a link.
    public let joinTarget: Meeting?

    public var next: Meeting? { upcoming.first }

    public static func empty(now: Date) -> TimelineSnapshot {
        TimelineSnapshot(now: now, ongoing: [], upcoming: [], status: .idle, joinTarget: nil)
    }
}

/// Pure "what is going on now / next" logic. All times are absolute `Date`s, so DST changes and
/// midnight rollovers need no special handling: a countdown is always a real elapsed duration.
public enum MeetingTimeline {
    public static func snapshot(
        meetings: [Meeting],
        filter: EventFilter?,
        now: Date,
        config: TimelineConfig = TimelineConfig()
    ) -> TimelineSnapshot {
        // All-day events have no start time to count down to; declined events and personal blocks
        // (FR-16) never drive the menu bar, join button or alerts.
        let relevant = meetings.filter { meeting in
            !meeting.isAllDay
                && meeting.myStatus != .declined
                && meeting.end > now
                && !(filter?.isPersonal(meeting) ?? false)
        }

        let ongoing = relevant.filter { $0.start <= now }.sorted(by: startOrder)
        let upcoming = relevant.filter { $0.start > now }.sorted(by: startOrder)

        func secondsUntil(_ meeting: Meeting) -> TimeInterval { meeting.start.timeIntervalSince(now) }

        let status: MenuBarStatus
        if let next = upcoming.first, secondsUntil(next) <= config.imminentWindow {
            status = .upcoming(next, secondsUntilStart: secondsUntil(next))
        } else if let current = ongoing.last {
            status = .ongoing(current)
        } else if let next = upcoming.first, secondsUntil(next) <= config.countdownHorizon {
            status = .upcoming(next, secondsUntilStart: secondsUntil(next))
        } else {
            status = .idle
        }

        // Joining prefers a call about to start, then the most recently started one, then the next one.
        let joinTarget = upcoming.first { $0.link != nil && secondsUntil($0) <= config.imminentWindow }
            ?? ongoing.last { $0.link != nil }
            ?? upcoming.first { $0.link != nil && secondsUntil($0) <= config.countdownHorizon }

        return TimelineSnapshot(now: now, ongoing: ongoing, upcoming: upcoming, status: status, joinTarget: joinTarget)
    }

    /// When the snapshot next needs recomputing, or nil if nothing will change without new input.
    /// Wake-ups are aligned to minute boundaries; far-off meetings sleep until they enter the countdown horizon.
    public static func nextWake(for snapshot: TimelineSnapshot, config: TimelineConfig = TimelineConfig()) -> Date? {
        let boundary = nextMinuteBoundary(after: snapshot.now)
        if !snapshot.ongoing.isEmpty { return boundary }
        guard let next = snapshot.next else { return nil }
        if next.start.timeIntervalSince(snapshot.now) <= config.countdownHorizon { return boundary }
        let entersHorizon = next.start.addingTimeInterval(-config.countdownHorizon)
        return max(boundary, ceilToMinute(entersHorizon))
    }

    /// The first whole minute strictly after `date`.
    public static func nextMinuteBoundary(after date: Date) -> Date {
        let minute = (date.timeIntervalSince1970 / 60).rounded(.down) + 1
        return Date(timeIntervalSince1970: minute * 60)
    }

    static func ceilToMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.up) * 60)
    }

    private static func startOrder(_ a: Meeting, _ b: Meeting) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if a.end != b.end { return a.end < b.end }
        if a.title != b.title { return a.title < b.title }
        return a.id < b.id
    }
}

import Foundation

public struct CalendarSnapshot: Sendable, Equatable {
    public let authorization: CalendarAuthorization
    public let calendars: [CalendarRef]
    public let meetings: [Meeting]
    public let fetchedAt: Date
}

/// Owns calendar permission state and turns store contents into `Meeting` values.
public actor CalendarService {
    public static let maxDays = 7

    private let dataSource: any CalendarDataSource
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let changeSource: @Sendable () -> AsyncStream<ChangeReason>
    private let debounce: Duration
    private let detector: MeetingLinkDetector

    public init(
        dataSource: any CalendarDataSource,
        changes: @escaping @Sendable () -> AsyncStream<ChangeReason>,
        debounce: Duration = .milliseconds(300),
        detector: MeetingLinkDetector = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.dataSource = dataSource
        self.changeSource = changes
        self.debounce = debounce
        self.detector = detector
        self.calendar = calendar
        self.now = now
    }

    /// The fetch window: from the start of today to the start of the day `days` days later.
    /// Calendar arithmetic keeps it correct across DST changes.
    public nonisolated func window(days: Int) -> DateInterval {
        let clamped = min(max(days, 1), Self.maxDays)
        let start = calendar.startOfDay(for: now())
        let end = calendar.date(byAdding: .day, value: clamped, to: start) ?? start.addingTimeInterval(Double(clamped) * 86_400)
        return DateInterval(start: start, end: end)
    }

    public func requestAccess() async -> CalendarAuthorization {
        await dataSource.requestAccess()
    }

    public func snapshot(days: Int, excludingCalendarIDs: Set<String>) async -> CalendarSnapshot {
        let authorization = await dataSource.authorization()
        guard authorization == .granted else {
            return CalendarSnapshot(authorization: authorization, calendars: [], meetings: [], fetchedAt: now())
        }
        let interval = window(days: days)
        let calendars = await dataSource.calendars()
        let events = await dataSource.events(
            from: interval.start,
            to: interval.end,
            excludingCalendarIDs: excludingCalendarIDs
        )
        let meetings = events
            .filter { !$0.isCanceled }
            .map { Meeting(raw: $0, link: detector.detect(url: $0.url, location: $0.location, notes: $0.notes)) }
            .sorted(by: Self.chronological)
        return CalendarSnapshot(authorization: authorization, calendars: calendars, meetings: meetings, fetchedAt: now())
    }

    /// Debounced change signals (event store, wake, day, time zone, clock). A burst yields one value.
    public nonisolated func updates() -> AsyncStream<ChangeReason> {
        let source = changeSource()
        let interval = debounce
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var pending: Task<Void, Never>?
                for await reason in source {
                    pending?.cancel()
                    pending = Task {
                        try? await Task.sleep(for: interval)
                        guard !Task.isCancelled else { return }
                        continuation.yield(reason)
                    }
                }
                pending?.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func chronological(_ a: Meeting, _ b: Meeting) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if a.end != b.end { return a.end < b.end }
        if a.title != b.title { return a.title < b.title }
        return a.id < b.id
    }
}

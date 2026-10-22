import Foundation
import Testing
@testable import NextCallCore

@Suite struct CalendarServiceTests {
    private func makeService(
        _ source: FakeDataSource,
        now: Date,
        calendar: Calendar = TestCalendars.utc,
        changes: @escaping @Sendable () -> AsyncStream<ChangeReason> = { AsyncStream { $0.finish() } },
        debounce: Duration = .milliseconds(20)
    ) -> CalendarService {
        CalendarService(dataSource: source, changes: changes, debounce: debounce, calendar: calendar, now: { now })
    }

    // MARK: Window

    @Test func windowCoversWholeDaysStartingToday() {
        let service = makeService(FakeDataSource(), now: makeDate(2026, 3, 10, 15, 42))
        let window = service.window(days: 2)
        #expect(window.start == makeDate(2026, 3, 10))
        #expect(window.end == makeDate(2026, 3, 12))
    }

    @Test(arguments: [(0, 1), (-3, 1), (1, 1), (7, 7), (99, 7)])
    func windowClampsDays(requested: Int, effective: Int) {
        let service = makeService(FakeDataSource(), now: makeDate(2026, 3, 10, 9))
        let window = service.window(days: requested)
        #expect(window.end == TestCalendars.utc.date(byAdding: .day, value: effective, to: makeDate(2026, 3, 10)))
    }

    @Test func windowIsDSTSafeOnSpringForward() {
        // US clocks jump forward on 2026-03-08, so that local day is 23 hours long.
        let ny = TestCalendars.newYork
        let service = makeService(FakeDataSource(), now: makeDate(2026, 3, 8, 12, calendar: ny), calendar: ny)
        #expect(service.window(days: 1).duration == 23 * 3600)
        #expect(service.window(days: 2).duration == 47 * 3600)
    }

    @Test func windowIsDSTSafeOnFallBack() {
        // 2026-11-01 has 25 hours in New York.
        let ny = TestCalendars.newYork
        let service = makeService(FakeDataSource(), now: makeDate(2026, 11, 1, 12, calendar: ny), calendar: ny)
        #expect(service.window(days: 1).duration == 25 * 3600)
    }

    @Test func windowRollsOverAtMidnight() {
        let late = makeService(FakeDataSource(), now: makeDate(2026, 3, 10, 23, 59))
        let early = makeService(FakeDataSource(), now: makeDate(2026, 3, 11, 0, 1))
        #expect(late.window(days: 1).start == makeDate(2026, 3, 10))
        #expect(early.window(days: 1).start == makeDate(2026, 3, 11))
    }

    // MARK: Snapshot

    @Test func snapshotWithoutAccessReturnsNothingAndDoesNotQueryEvents() async {
        let source = FakeDataSource(status: .denied, events: [makeEvent(start: makeDate(2026, 3, 10, 10))])
        let service = makeService(source, now: makeDate(2026, 3, 10, 9))
        let snapshot = await service.snapshot(days: 2, excludingCalendarIDs: [])
        #expect(snapshot.authorization == .denied)
        #expect(snapshot.meetings.isEmpty)
        #expect(await source.eventRequests.isEmpty)
    }

    @Test func snapshotQueriesWindowAndPassesExcludedCalendars() async {
        let source = FakeDataSource()
        let service = makeService(source, now: makeDate(2026, 3, 10, 9))
        _ = await service.snapshot(days: 3, excludingCalendarIDs: ["cal-x"])
        let request = await source.eventRequests.first
        #expect(request?.start == makeDate(2026, 3, 10))
        #expect(request?.end == makeDate(2026, 3, 13))
        #expect(request?.excluded == ["cal-x"])
    }

    @Test func snapshotDropsCanceledAndSortsChronologically() async {
        let events = [
            makeEvent("c", title: "Late", start: makeDate(2026, 3, 10, 15)),
            makeEvent("x", title: "Canceled", start: makeDate(2026, 3, 10, 9), canceled: true),
            makeEvent("a", title: "Early", start: makeDate(2026, 3, 10, 8)),
            makeEvent("b", title: "Mid", start: makeDate(2026, 3, 10, 11)),
        ]
        let source = FakeDataSource(calendars: [makeCalendarRef()], events: events)
        let service = makeService(source, now: makeDate(2026, 3, 10, 7))
        let snapshot = await service.snapshot(days: 1, excludingCalendarIDs: [])
        #expect(snapshot.meetings.map(\.title) == ["Early", "Mid", "Late"])
        #expect(snapshot.calendars.count == 1)
    }

    @Test func sameStartTimesAreOrderedByEndThenTitleThenID() async {
        let start = makeDate(2026, 3, 10, 10)
        let events = [
            makeEvent("2", title: "B", start: start, minutes: 30),
            makeEvent("1", title: "A", start: start, minutes: 30),
            makeEvent("0", title: "Z", start: start, minutes: 15),
        ]
        let service = makeService(FakeDataSource(events: events), now: makeDate(2026, 3, 10, 7))
        let snapshot = await service.snapshot(days: 1, excludingCalendarIDs: [])
        #expect(snapshot.meetings.map(\.id) == ["0", "1", "2"])
    }

    @Test func revokedPermissionEmptiesTheNextSnapshot() async {
        let source = FakeDataSource(events: [makeEvent(start: makeDate(2026, 3, 10, 10))])
        let service = makeService(source, now: makeDate(2026, 3, 10, 9))
        #expect(await service.snapshot(days: 1, excludingCalendarIDs: []).meetings.count == 1)
        await source.setStatus(.denied)
        let after = await service.snapshot(days: 1, excludingCalendarIDs: [])
        #expect(after.authorization == .denied)
        #expect(after.meetings.isEmpty)
    }

    @Test func requestAccessReturnsNewStateFromDataSource() async {
        let source = FakeDataSource(status: .notDetermined)
        let service = makeService(source, now: makeDate(2026, 3, 10, 9))
        #expect(await service.requestAccess() == .granted)
        #expect(await source.accessRequests == 1)
    }

    @Test func meetingEndNeverPrecedesStart() {
        let event = RawEvent(
            id: "e", title: "Odd", start: makeDate(2026, 3, 10, 10), end: makeDate(2026, 3, 10, 9),
            calendar: makeCalendarRef()
        )
        let meeting = Meeting(raw: event)
        #expect(meeting.end == meeting.start)
    }

    // MARK: Updates

    @Test func burstOfChangesIsDebouncedToOneRefresh() async throws {
        let (source, continuation) = AsyncStream<ChangeReason>.makeStream()
        let service = makeService(FakeDataSource(), now: makeDate(2026, 3, 10, 9), changes: { source })
        let collector = Collector<ChangeReason>()
        let task = Task {
            for await reason in service.updates() { await collector.add(reason) }
        }
        continuation.yield(.eventStore)
        continuation.yield(.eventStore)
        continuation.yield(.wake)
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        #expect(await collector.items == [.wake])
    }

    @Test func separatedChangesProduceSeparateRefreshes() async throws {
        let (source, continuation) = AsyncStream<ChangeReason>.makeStream()
        let service = makeService(FakeDataSource(), now: makeDate(2026, 3, 10, 9), changes: { source })
        let collector = Collector<ChangeReason>()
        let task = Task {
            for await reason in service.updates() { await collector.add(reason) }
        }
        continuation.yield(.dayChanged)
        try await Task.sleep(for: .milliseconds(200))
        continuation.yield(.timeZone)
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        #expect(await collector.items == [.dayChanged, .timeZone])
    }
}

@Suite struct RefreshPerformanceTests {
    /// PRD section 8: a refresh of 200 events (mapping, link detection, sorting) stays under 100 ms.
    /// Measured in a Debug build, which is slower than the shipped Release build.
    @Test func refreshingTwoHundredEventsIsUnderOneHundredMilliseconds() async {
        let notes = LinkFixture.all.map { ($0.url.flatMap { URL(string: $0) }, $0.location, $0.notes) }
        let base = makeDate(2026, 3, 10, 8)
        let events = (0..<200).map { index -> RawEvent in
            let sample = notes[index % notes.count]
            return RawEvent(
                id: "e\(index)", title: "Event \(index)",
                start: base.addingTimeInterval(Double(index) * 600), end: base.addingTimeInterval(Double(index) * 600 + 1800),
                calendar: makeCalendarRef(), url: sample.0, location: sample.1, notes: sample.2, attendeeCount: 3, otherAttendeeCount: 2
            )
        }
        let service = CalendarService(
            dataSource: FakeDataSource(events: events),
            changes: { AsyncStream { $0.finish() } },
            calendar: TestCalendars.utc,
            now: { base }
        )
        let start = ContinuousClock.now
        let snapshot = await service.snapshot(days: 7, excludingCalendarIDs: [])
        let elapsed = ContinuousClock.now - start
        #expect(snapshot.meetings.count == 200)
        #expect(elapsed < .milliseconds(100), "took \(elapsed)")
    }
}

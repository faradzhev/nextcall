import Foundation
import Testing
@testable import NextCallCore

final class ManualClock: SchedulerClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private var sleepers: [UUID: (deadline: Date, continuation: CheckedContinuation<Void, Error>)] = [:]

    init(_ start: Date) { current = start }

    var now: Date { lock.withLock { current } }
    var sleeperCount: Int { lock.withLock { sleepers.count } }

    func sleep(until deadline: Date) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if deadline <= current {
                    lock.unlock()
                    continuation.resume()
                } else if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else {
                    sleepers[id] = (deadline, continuation)
                    lock.unlock()
                }
            }
        } onCancel: {
            let entry = lock.withLock { sleepers.removeValue(forKey: id) }
            entry?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(to date: Date) {
        let due = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
            current = date
            let ids = sleepers.filter { $0.value.deadline <= date }.map(\.key)
            return ids.compactMap { sleepers.removeValue(forKey: $0)?.continuation }
        }
        for continuation in due { continuation.resume() }
    }
}

@MainActor
@Suite struct MeetingSchedulerTests {
    private let link = MeetingLink(provider: .zoom, url: URL(string: "https://zoom.us/j/123456789")!, nativeURL: nil)

    private func meeting(_ id: String, _ start: Date, minutes: Int = 30) -> Meeting {
        Meeting(raw: makeEvent(id, start: start, minutes: minutes), link: link)
    }

    /// Waits until the scheduler loop has gone to sleep on the manual clock.
    private func waitForSleeper(_ clock: ManualClock, count: Int = 1) async {
        for _ in 0..<2_000 where clock.sleeperCount < count {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    private func waitForCallbacks(_ box: SnapshotBox, count: Int) async {
        for _ in 0..<2_000 where box.snapshots.count < count {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    final class SnapshotBox {
        var snapshots: [TimelineSnapshot] = []
    }

    @Test func publishesImmediatelyOnUpdate() {
        let clock = ManualClock(makeDate(2026, 3, 10, 10, 0))
        let box = SnapshotBox()
        let scheduler = MeetingScheduler(clock: clock) { box.snapshots.append($0) }
        scheduler.update(meetings: [meeting("a", makeDate(2026, 3, 10, 10, 30))], filter: nil)
        #expect(box.snapshots.count == 1)
        #expect(box.snapshots[0].next?.id == "a")
        scheduler.stop()
    }

    @Test func ticksOncePerMinuteAndFlipsToOngoingAtStart() async {
        let clock = ManualClock(makeDate(2026, 3, 10, 10, 0).addingTimeInterval(15))
        let box = SnapshotBox()
        let scheduler = MeetingScheduler(clock: clock) { box.snapshots.append($0) }
        scheduler.update(meetings: [meeting("a", makeDate(2026, 3, 10, 10, 2))], filter: nil)
        await waitForSleeper(clock)

        clock.advance(to: makeDate(2026, 3, 10, 10, 1))
        await waitForCallbacks(box, count: 2)
        #expect(box.snapshots.last?.status == .upcoming(meeting("a", makeDate(2026, 3, 10, 10, 2)), secondsUntilStart: 60))

        await waitForSleeper(clock)
        clock.advance(to: makeDate(2026, 3, 10, 10, 2))
        await waitForCallbacks(box, count: 3)
        #expect(box.snapshots.last?.ongoing.map(\.id) == ["a"])
        scheduler.stop()
    }

    @Test func goesQuietWhenThereIsNothingLeftToCountDown() async {
        let clock = ManualClock(makeDate(2026, 3, 10, 10, 0))
        let box = SnapshotBox()
        let scheduler = MeetingScheduler(clock: clock) { box.snapshots.append($0) }
        scheduler.update(meetings: [meeting("a", makeDate(2026, 3, 10, 9, 0))], filter: nil) // already over
        try? await Task.sleep(for: .milliseconds(50))
        #expect(clock.sleeperCount == 0)
        #expect(box.snapshots.count == 1)
        scheduler.stop()
    }

    @Test func farMeetingSleepsOnceUntilItEntersTheHorizon() async {
        let clock = ManualClock(makeDate(2026, 3, 10, 10, 0))
        let box = SnapshotBox()
        let scheduler = MeetingScheduler(clock: clock) { box.snapshots.append($0) }
        scheduler.update(meetings: [meeting("a", makeDate(2026, 3, 11, 9, 0))], filter: nil)
        await waitForSleeper(clock)
        clock.advance(to: makeDate(2026, 3, 10, 10, 1)) // too early: not the wake time
        try? await Task.sleep(for: .milliseconds(30))
        #expect(box.snapshots.count == 1)
        clock.advance(to: makeDate(2026, 3, 11, 1, 0))
        await waitForCallbacks(box, count: 2)
        #expect(box.snapshots.last?.status != .idle)
        scheduler.stop()
    }

    @Test func newInputReplacesThePendingTimer() async {
        let clock = ManualClock(makeDate(2026, 3, 10, 10, 0))
        let box = SnapshotBox()
        let scheduler = MeetingScheduler(clock: clock) { box.snapshots.append($0) }
        scheduler.update(meetings: [meeting("a", makeDate(2026, 3, 10, 10, 30))], filter: nil)
        await waitForSleeper(clock)
        scheduler.update(meetings: [meeting("b", makeDate(2026, 3, 10, 10, 20))], filter: nil)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(clock.sleeperCount == 1) // the old sleeper was cancelled, not leaked
        #expect(scheduler.snapshot.next?.id == "b")
        scheduler.stop()
    }

    @Test func stopCancelsTheTimer() async {
        let clock = ManualClock(makeDate(2026, 3, 10, 10, 0))
        let scheduler = MeetingScheduler(clock: clock) { _ in }
        scheduler.update(meetings: [meeting("a", makeDate(2026, 3, 10, 10, 30))], filter: nil)
        await waitForSleeper(clock)
        scheduler.stop()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(clock.sleeperCount == 0)
    }

    @Test func midnightRolloverKeepsCountingDown() async {
        let clock = ManualClock(makeDate(2026, 3, 10, 23, 58))
        let box = SnapshotBox()
        let scheduler = MeetingScheduler(clock: clock) { box.snapshots.append($0) }
        let m = meeting("a", makeDate(2026, 3, 11, 0, 1))
        scheduler.update(meetings: [m], filter: nil)
        await waitForSleeper(clock)
        clock.advance(to: makeDate(2026, 3, 11, 0, 0))
        await waitForCallbacks(box, count: 3)
        #expect(box.snapshots.last?.status == .upcoming(m, secondsUntilStart: 60))
        scheduler.stop()
    }
}

@Suite struct SystemSchedulerClockTests {
    @Test func sleepsUntilTheDeadlineAndReturnsImmediatelyForThePast() async throws {
        let clock = SystemSchedulerClock()
        let start = ContinuousClock.now
        try await clock.sleep(until: clock.now.addingTimeInterval(0.05))
        #expect(ContinuousClock.now - start >= .milliseconds(40))
        let again = ContinuousClock.now
        try await clock.sleep(until: clock.now.addingTimeInterval(-10))
        #expect(ContinuousClock.now - again < .milliseconds(40))
    }

    @Test func cancellationEndsTheSleep() async {
        let clock = SystemSchedulerClock()
        let task = Task { try await clock.sleep(until: clock.now.addingTimeInterval(3600)) }
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}

import Foundation

/// Keeps a `TimelineSnapshot` current. Recomputes on new input and then sleeps until the next
/// minute boundary (or until a far-off meeting enters the countdown horizon). It never polls:
/// with nothing to count down to, it does not wake at all.
@MainActor
public final class MeetingScheduler {
    public private(set) var snapshot: TimelineSnapshot

    private let clock: any SchedulerClock
    private let config: TimelineConfig
    private let onChange: @MainActor (TimelineSnapshot) -> Void
    private var meetings: [Meeting] = []
    private var filter: EventFilter?
    private var loop: Task<Void, Never>?

    public init(
        clock: any SchedulerClock = SystemSchedulerClock(),
        config: TimelineConfig = TimelineConfig(),
        onChange: @escaping @MainActor (TimelineSnapshot) -> Void
    ) {
        self.clock = clock
        self.config = config
        self.onChange = onChange
        snapshot = .empty(now: clock.now)
    }

    public func update(meetings: [Meeting], filter: EventFilter?) {
        self.meetings = meetings
        self.filter = filter
        recompute()
        restartLoop()
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    private func recompute() {
        let new = MeetingTimeline.snapshot(meetings: meetings, filter: filter, now: clock.now, config: config)
        snapshot = new
        onChange(new)
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let wake = MeetingTimeline.nextWake(for: snapshot, config: config) else { return }
                let clock = clock
                do { try await clock.sleep(until: wake) } catch { return }
                guard !Task.isCancelled else { return }
                recompute()
            }
        }
    }
}

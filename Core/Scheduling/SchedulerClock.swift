import Foundation

/// Injected time source so scheduling logic is testable (DST, midnight, wake-ups) without real waiting.
public protocol SchedulerClock: Sendable {
    var now: Date { get }
    /// Suspends until `deadline`; throws `CancellationError` if the task is cancelled first.
    func sleep(until deadline: Date) async throws
}

public struct SystemSchedulerClock: SchedulerClock {
    public init() {}

    public var now: Date { Date() }

    public func sleep(until deadline: Date) async throws {
        // ContinuousClock keeps counting while the Mac sleeps, so a due timer fires promptly after wake.
        try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
    }
}

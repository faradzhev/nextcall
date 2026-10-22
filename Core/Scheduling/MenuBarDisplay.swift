import Foundation

public enum MenuBarMode: String, Codable, CaseIterable, Sendable {
    case iconOnly
    case countdown
    case titleAndCountdown
}

public enum Countdown: Sendable, Equatable {
    /// Whole minutes until the start, rounded up, at least 1.
    case minutes(Int)
    case now
}

/// What the status item should show, as data; the app turns it into localized text.
public struct MenuBarDisplay: Sendable, Equatable {
    public let title: String?
    public let countdown: Countdown?
    /// Within the imminent window: the status item takes the accent colour.
    public let isImminent: Bool

    public static let iconOnly = MenuBarDisplay(title: nil, countdown: nil, isImminent: false)

    public static func make(
        status: MenuBarStatus,
        mode: MenuBarMode,
        titleLength: Int,
        imminentWindow: TimeInterval = TimelineConfig().imminentWindow
    ) -> MenuBarDisplay {
        switch status {
        case .idle:
            return .iconOnly
        case let .upcoming(meeting, seconds):
            let imminent = seconds <= imminentWindow
            guard mode != .iconOnly else { return MenuBarDisplay(title: nil, countdown: nil, isImminent: imminent) }
            let minutes = max(1, Int((seconds / 60).rounded(.up)))
            return MenuBarDisplay(
                title: mode == .titleAndCountdown ? truncated(meeting.title, to: titleLength) : nil,
                countdown: .minutes(minutes),
                isImminent: imminent
            )
        case let .ongoing(meeting):
            guard mode != .iconOnly else { return .iconOnly }
            return MenuBarDisplay(
                title: mode == .titleAndCountdown ? truncated(meeting.title, to: titleLength) : nil,
                countdown: .now,
                isImminent: false
            )
        }
    }

    static func truncated(_ title: String, to length: Int) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let limit = max(length, 1)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(max(limit - 1, 1))).trimmingCharacters(in: .whitespaces) + "…"
    }
}

import Foundation
import NextCallCore

/// Localized text for the menu bar item and popover header.
enum StatusText {
    /// "12 min", "2 h 5 min", "3 h".
    static func duration(minutes: Int) -> String {
        if minutes < 60 { return String(localized: "\(minutes) min") }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? String(localized: "\(hours) h") : String(localized: "\(hours) h \(rest) min")
    }

    /// Text next to the menu bar icon, or nil for icon only. Compact form when a title is shown.
    static func menuBarText(_ display: MenuBarDisplay) -> String? {
        guard let countdown = display.countdown else { return nil }
        let withTitle = display.title != nil
        let time: String
        switch countdown {
        case .now:
            time = String(localized: "now")
        case let .minutes(total):
            time = compactCountdown(minutes: total, prefixed: !withTitle)
        }
        guard let title = display.title else { return time }
        return "\(title) · \(time)"
    }

    private static func compactCountdown(minutes: Int, prefixed: Bool) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (prefixed, minutes < 60, rest == 0) {
        case (true, true, _): return String(localized: "in \(minutes)m")
        case (true, false, true): return String(localized: "in \(hours)h")
        case (true, false, false): return String(localized: "in \(hours)h \(rest)m")
        case (false, true, _): return String(localized: "\(minutes)m")
        case (false, false, true): return String(localized: "\(hours)h")
        case (false, false, false): return String(localized: "\(hours)h \(rest)m")
        }
    }

    /// One-line summary for the popover header and the status item's accessibility label.
    static func summary(for status: MenuBarStatus) -> String {
        switch status {
        case .idle:
            return String(localized: "Nothing coming up")
        case let .ongoing(meeting):
            return String(localized: "Now: \(displayTitle(meeting))")
        case let .upcoming(meeting, seconds):
            let minutes = max(1, Int((seconds / 60).rounded(.up)))
            return String(localized: "Next: \(displayTitle(meeting)) in \(duration(minutes: minutes))")
        }
    }

    static func displayTitle(_ meeting: Meeting) -> String {
        meeting.title.isEmpty ? String(localized: "Untitled event") : meeting.title
    }
}

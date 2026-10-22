import Foundation

public struct EventFilterRules: Sendable, Equatable {
    public static let defaultIgnoreKeywords = ["Lunch", "Busy", "Focus", "OOO", "Out of office", "Commute", "Hold", "Block"]

    public var ignoreKeywords: [String]
    /// Treat events with no attendees other than the user as personal blocks.
    public var ignoreSoloEvents: Bool
    /// Treat events whose availability is Free as personal blocks.
    public var ignoreFreeEvents: Bool

    public init(
        ignoreKeywords: [String] = EventFilterRules.defaultIgnoreKeywords,
        ignoreSoloEvents: Bool = true,
        ignoreFreeEvents: Bool = true
    ) {
        self.ignoreKeywords = ignoreKeywords
        self.ignoreSoloEvents = ignoreSoloEvents
        self.ignoreFreeEvents = ignoreFreeEvents
    }
}

public enum EventClassification: Sendable, Equatable {
    public enum PersonalReason: Sendable, Equatable {
        case solo
        case free
        case keyword(String)
    }

    case meeting
    case personal(PersonalReason)

    public var isPersonal: Bool {
        if case .personal = self { return true }
        return false
    }
}

/// Decides meeting vs personal block (FR-16). Rules run in order:
/// 1. a detected meeting link always makes it a meeting;
/// 2. otherwise personal if it has no other attendees, is marked Free, or its title contains an ignore keyword
///    (whole word or phrase, case-insensitive).
public struct EventFilter: Sendable {
    private let rules: EventFilterRules
    private let keywords: [(text: String, pattern: Pattern)]

    public init(rules: EventFilterRules = EventFilterRules()) {
        self.rules = rules
        keywords = rules.ignoreKeywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { keyword in
                // `\b` only works next to word characters, so use lookarounds that also accept punctuation edges.
                let escaped = NSRegularExpression.escapedPattern(for: keyword)
                return (keyword, Pattern(#"(?<![\p{L}\p{N}_])"# + escaped + #"(?![\p{L}\p{N}_])"#))
            }
    }

    public func classify(_ meeting: Meeting) -> EventClassification {
        if meeting.link != nil { return .meeting }
        if rules.ignoreSoloEvents && meeting.otherAttendeeCount == 0 { return .personal(.solo) }
        if rules.ignoreFreeEvents && meeting.availability == .free { return .personal(.free) }
        if let hit = keywords.first(where: { $0.pattern.hasMatch(in: meeting.title) }) {
            return .personal(.keyword(hit.text))
        }
        return .meeting
    }

    public func isPersonal(_ meeting: Meeting) -> Bool {
        classify(meeting).isPersonal
    }
}

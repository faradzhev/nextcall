import Foundation

/// URLs behind the event context menu (FR-14).
public enum MeetingActions {
    /// `mailto:` to all other attendees, or nil when there are none.
    public static func mailtoURL(for meeting: Meeting) -> URL? {
        guard !meeting.attendeeEmails.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = meeting.attendeeEmails.joined(separator: ",")
        if !meeting.title.isEmpty {
            components.queryItems = [URLQueryItem(name: "subject", value: meeting.title)]
        }
        return components.url
    }

    /// Deep link that makes Calendar show the event.
    public static func calendarURL(for meeting: Meeting) -> URL? {
        var components = URLComponents()
        components.scheme = "ical"
        components.host = "ekevent"
        components.path = "/" + meeting.eventIdentifier
        components.queryItems = [
            URLQueryItem(name: "method", value: "show"),
            URLQueryItem(name: "options", value: "more"),
        ]
        return components.url
    }
}

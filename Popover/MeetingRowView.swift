import NextCallCore
import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting
    let now: Date
    /// A personal block (FR-16) shown dimmed instead of hidden.
    var isIgnored = false

    /// Fixed so the popover can size its list without measuring.
    static let height: CGFloat = 36

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(meeting.calendar.color.swiftUIColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title.isEmpty ? String(localized: "Untitled event") : meeting.title)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if meeting.attendeeCount > 1 {
                Label {
                    Text(verbatim: "\(meeting.attendeeCount)")
                } icon: {
                    Image(systemName: "person.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(height: Self.height)
        .opacity(meeting.isPast(at: now) || isIgnored ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var timeText: String {
        if meeting.isAllDay { return String(localized: "All day") }
        return (meeting.start..<meeting.end).formatted(Date.IntervalFormatStyle(time: .shortened))
    }

    private var accessibilityText: String {
        let title = meeting.title.isEmpty ? String(localized: "Untitled event") : meeting.title
        var parts = [title, timeText]
        if meeting.attendeeCount > 1 {
            parts.append(String(localized: "\(meeting.attendeeCount) attendees"))
        }
        return parts.joined(separator: ", ")
    }
}

extension CalendarColor {
    var swiftUIColor: Color { Color(red: red, green: green, blue: blue) }
}

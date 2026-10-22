import NextCallCore
import SwiftUI

struct MeetingRowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorSchemeContrast) private var contrast
    let meeting: Meeting
    let now: Date
    /// A personal block (FR-16) shown dimmed instead of hidden.
    var isIgnored = false
    var isSelected = false

    /// Fixed so the popover can size its list without measuring.
    static let height: CGFloat = 44

    var body: some View {
        let ongoing = meeting.isOngoing(at: now)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(meeting.calendar.color.swiftUIColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(StatusText.displayTitle(meeting))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(timeText)
                        if let link = meeting.link {
                            Image(systemName: "video.fill")
                                .accessibilityHidden(true)
                            Text(link.provider.displayName)
                        }
                        if meeting.attendeeCount > 1 {
                            Image(systemName: "person.2")
                                .accessibilityHidden(true)
                            Text(verbatim: "\(meeting.attendeeCount)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityText)

                if ongoing {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .controlSize(.mini)
                        .accessibilityLabel(Text("Elapsed time"))
                }
            }

            Spacer(minLength: 8)

            if meeting.link != nil {
                Button("Join") { appState.join(meeting) }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(Text("Join \(StatusText.displayTitle(meeting))"))
            }
        }
        .padding(.horizontal, 6)
        .frame(height: Self.height)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor(ongoing: ongoing))
        }
        // Dimmed rows stay readable with Increase Contrast.
        .opacity(meeting.isPast(at: now) || isIgnored ? (contrast == .increased ? 0.7 : 0.5) : 1)
        .contentShape(Rectangle())
        .contextMenu { contextMenu }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if meeting.link != nil {
            Button("Join") { appState.join(meeting) }
            Button("Copy link") { appState.copyLink(meeting) }
        }
        Button("Open in Calendar") { appState.openInCalendar(meeting) }
        if !meeting.attendeeEmails.isEmpty {
            Button("Email attendees") { appState.emailAttendees(meeting) }
        }
        Divider()
        Button("Hide this event") { appState.hide(meeting) }
        if appState.canIgnoreTitle(meeting) {
            Button("Ignore events titled “\(meeting.title.trimmingCharacters(in: .whitespacesAndNewlines))”") {
                appState.ignoreEvents(titled: meeting)
            }
        }
    }

    private func backgroundColor(ongoing: Bool) -> Color {
        let strong = contrast == .increased
        if isSelected { return Color.accentColor.opacity(strong ? 0.45 : 0.22) }
        return ongoing ? Color.accentColor.opacity(strong ? 0.28 : 0.12) : .clear
    }

    private var progress: Double {
        let duration = meeting.end.timeIntervalSince(meeting.start)
        guard duration > 0 else { return 0 }
        return min(max(now.timeIntervalSince(meeting.start) / duration, 0), 1)
    }

    private var timeText: String {
        if meeting.isAllDay { return String(localized: "All day") }
        return (meeting.start..<meeting.end).formatted(Date.IntervalFormatStyle(time: .shortened))
    }

    private var accessibilityText: String {
        var parts = [StatusText.displayTitle(meeting), timeText]
        if let link = meeting.link { parts.append(link.provider.displayName) }
        if meeting.attendeeCount > 1 {
            parts.append(String(localized: "\(meeting.attendeeCount) attendees"))
        }
        return parts.joined(separator: ", ")
    }
}

extension CalendarColor {
    var swiftUIColor: Color { Color(red: red, green: green, blue: blue) }
}

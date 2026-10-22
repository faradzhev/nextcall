import NextCallCore
import SwiftUI

struct MeetingListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedID: String?
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let maxHeight: CGFloat = 400
    private static let padding: CGFloat = 12
    private static let sectionSpacing: CGFloat = 14
    private static let rowSpacing: CGFloat = 6

    var body: some View {
        let sections = appState.sections
        if sections.isEmpty {
            Text("No upcoming meetings")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            let meetings = sections.flatMap(\.meetings)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                        ForEach(sections) { section in
                            DaySectionView(section: section, now: appState.now, selectedID: selectedID)
                        }
                    }
                    .padding(Self.padding)
                }
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .onAppear { isFocused = true }
                .onKeyPress(.downArrow) { move(1, in: meetings, proxy: proxy) }
                .onKeyPress(.upArrow) { move(-1, in: meetings, proxy: proxy) }
                .onKeyPress(.return) { joinSelected(in: meetings) }
                .accessibilityIdentifier("popover.list")
            }
            .frame(height: min(Self.contentHeight(for: sections), Self.maxHeight))
        }
    }

    private func move(_ delta: Int, in meetings: [Meeting], proxy: ScrollViewProxy) -> KeyPress.Result {
        guard !meetings.isEmpty else { return .ignored }
        let current = meetings.firstIndex { $0.id == selectedID }
        let next: Int
        if let current {
            next = min(max(current + delta, 0), meetings.count - 1)
        } else {
            // First arrow press: start from the next meeting (down) or the last one (up).
            next = delta > 0 ? (meetings.firstIndex { !$0.isPast(at: appState.now) } ?? 0) : meetings.count - 1
        }
        selectedID = meetings[next].id
        if reduceMotion {
            proxy.scrollTo(meetings[next].id, anchor: .center)
        } else {
            withAnimation { proxy.scrollTo(meetings[next].id, anchor: .center) }
        }
        return .handled
    }

    private func joinSelected(in meetings: [Meeting]) -> KeyPress.Result {
        guard let meeting = meetings.first(where: { $0.id == selectedID }), meeting.link != nil else { return .ignored }
        appState.join(meeting)
        return .handled
    }

    /// Row and header heights are fixed, so the list height is computed instead of measured.
    private static func contentHeight(for sections: [DaySection]) -> CGFloat {
        let sectionHeights = sections.map { section -> CGFloat in
            let rows = CGFloat(section.meetings.count)
            return DaySectionView.headerHeight + rowSpacing
                + rows * MeetingRowView.height + max(rows - 1, 0) * rowSpacing
        }
        return sectionHeights.reduce(0, +)
            + CGFloat(max(sections.count - 1, 0)) * sectionSpacing
            + 2 * padding
    }
}

private struct DaySectionView: View {
    @Environment(AppState.self) private var appState
    let section: DaySection
    let now: Date
    let selectedID: String?

    static let headerHeight: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(height: Self.headerHeight, alignment: .leading)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.meetings) { meeting in
                MeetingRowView(
                    meeting: meeting,
                    now: now,
                    isIgnored: appState.isIgnored(meeting),
                    isSelected: meeting.id == selectedID
                )
                .id(meeting.id)
            }
        }
    }

    private var title: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(section.day) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(section.day) { return String(localized: "Tomorrow") }
        return section.day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

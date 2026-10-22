import NextCallCore
import SwiftUI

struct MeetingListView: View {
    @Environment(AppState.self) private var appState

    private static let maxHeight: CGFloat = 440
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
            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    ForEach(sections) { section in
                        DaySectionView(section: section, now: appState.now)
                    }
                }
                .padding(Self.padding)
            }
            .frame(height: min(Self.contentHeight(for: sections), Self.maxHeight))
        }
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
    let section: DaySection
    let now: Date

    static let headerHeight: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(height: Self.headerHeight, alignment: .leading)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.meetings) { meeting in
                MeetingRowView(meeting: meeting, now: now)
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

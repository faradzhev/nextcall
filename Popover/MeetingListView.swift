import NextCallCore
import SwiftUI

struct MeetingListView: View {
    @Environment(AppState.self) private var appState
    @State private var contentHeight: CGFloat = 0

    private static let maxHeight: CGFloat = 440

    var body: some View {
        let sections = appState.sections
        if sections.isEmpty {
            Text("No upcoming meetings")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections) { section in
                        DaySectionView(section: section, now: appState.now)
                    }
                }
                .padding(12)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                }
            }
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
            .frame(height: min(max(contentHeight, 1), Self.maxHeight))
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DaySectionView: View {
    let section: DaySection
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
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

import NextCallCore
import SwiftUI

struct CalendarsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.authorization != .granted {
            CalendarAccessView()
                .frame(maxHeight: .infinity)
        } else if appState.calendarGroups.isEmpty {
            Text("No calendars found.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                CalendarToggleSections()
            }
            .formStyle(.grouped)
        }
    }
}

/// One section of calendar toggles per account, with colour dots. Shared by Settings and onboarding.
struct CalendarToggleSections: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ForEach(appState.calendarGroups) { group in
            Section(group.source.title.isEmpty ? String(localized: "Other") : group.source.title) {
                ForEach(group.calendars) { calendar in
                    Toggle(isOn: appState.settings.calendarEnabledBinding(for: calendar.id)) {
                        Label {
                            Text(calendar.title)
                        } icon: {
                            Circle()
                                .fill(calendar.color.swiftUIColor)
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }
}

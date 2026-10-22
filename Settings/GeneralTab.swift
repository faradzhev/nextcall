import NextCallCore
import SwiftUI

struct GeneralTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let settings = appState.settings
        Form {
            Stepper(
                value: settings.binding(\.daysAhead),
                in: 1...CalendarService.maxDays
            ) {
                Text("Days ahead: \(settings.value.daysAhead)")
            }

            Toggle("Show all-day events", isOn: settings.binding(\.showAllDay))
            Toggle("Hide declined events", isOn: settings.binding(\.hideDeclined))

            Picker("Past events", selection: settings.binding(\.pastEvents)) {
                Text("Dimmed").tag(PastEventsMode.dimmed)
                Text("Hidden").tag(PastEventsMode.hidden)
            }
        }
        .formStyle(.grouped)
    }
}

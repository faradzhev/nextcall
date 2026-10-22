import NextCallCore
import SwiftUI

struct GeneralTab: View {
    @Environment(AppState.self) private var appState
    @State private var newKeyword = ""

    var body: some View {
        let settings = appState.settings
        Form {
            Section {
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

            Section {
                Toggle("Events without other attendees", isOn: settings.binding(\.ignoreSoloEvents))
                Toggle("Events marked as Free", isOn: settings.binding(\.ignoreFreeEvents))

                Picker("Show ignored events as", selection: settings.binding(\.ignoredEvents)) {
                    Text("Dimmed").tag(IgnoredEventsMode.dimmed)
                    Text("Hidden").tag(IgnoredEventsMode.hidden)
                }

                ForEach(settings.value.ignoreKeywords, id: \.self) { keyword in
                    HStack {
                        Text(keyword)
                        Spacer()
                        Button {
                            settings.update { $0.ignoreKeywords.removeAll { $0 == keyword } }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Remove \(keyword)"))
                    }
                }

                TextField("Add keyword", text: $newKeyword)
                    .onSubmit(addKeyword)

                Button("Reset keywords") {
                    settings.update { $0.ignoreKeywords = EventFilterRules.defaultIgnoreKeywords }
                }
            } header: {
                Text("Ignored events")
            } footer: {
                Text("Events with a meeting link are never ignored. A keyword matches whole words in the title.")
            }
        }
        .formStyle(.grouped)
    }

    private func addKeyword() {
        let keyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        newKeyword = ""
        guard !keyword.isEmpty else { return }
        appState.settings.update { settings in
            let exists = settings.ignoreKeywords.contains { $0.caseInsensitiveCompare(keyword) == .orderedSame }
            if !exists { settings.ignoreKeywords.append(keyword) }
        }
    }
}

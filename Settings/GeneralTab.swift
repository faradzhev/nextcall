import NextCallCore
import SwiftUI

struct GeneralTab: View {
    @Environment(AppState.self) private var appState
    @State private var newKeyword = ""

    var body: some View {
        let settings = appState.settings
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.launchAtLogin.isOn },
                    set: { appState.launchAtLogin.setEnabled($0) }
                ))
                if appState.launchAtLogin.status == .requiresApproval {
                    HStack {
                        Text("Allow NextCall in System Settings › Login Items to finish enabling this.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { appState.launchAtLogin.openSystemSettings() }
                    }
                }
                if let error = appState.launchAtLogin.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Menu bar") {
                Picker("Show in menu bar", selection: settings.binding(\.menuBarMode)) {
                    Text("Icon only").tag(MenuBarMode.iconOnly)
                    Text("Countdown").tag(MenuBarMode.countdown)
                    Text("Title and countdown").tag(MenuBarMode.titleAndCountdown)
                }
                Stepper(
                    value: settings.binding(\.menuBarTitleLength),
                    in: AppSettings.titleLengthRange
                ) {
                    Text("Title length: \(settings.value.menuBarTitleLength)")
                }
                .disabled(settings.value.menuBarMode != .titleAndCountdown)
            }

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

                if !settings.value.hiddenMeetings.isEmpty {
                    HStack {
                        Text("Hidden events: \(settings.value.hiddenMeetings.count)")
                        Spacer()
                        Button("Show all") { appState.unhideAll() }
                    }
                }
            } header: {
                Text("Ignored events")
            } footer: {
                Text("Events with a meeting link are never ignored. A keyword matches whole words in the title.")
            }
        }
        .formStyle(.grouped)
        .onAppear { appState.launchAtLogin.refresh() }
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

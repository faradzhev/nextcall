import AppKit
import NextCallCore
import SwiftUI

struct NotificationsTab: View {
    @Environment(AppState.self) private var appState

    private static let leadOptions = [0, 1, 2, 3, 5, 10, 15]

    var body: some View {
        let settings = appState.settings
        Form {
            Section {
                Toggle("Notify before meetings", isOn: settings.binding(\.notificationsEnabled))

                Picker("Notify", selection: settings.binding(\.notificationLeadMinutes)) {
                    ForEach(leadChoices(including: settings.value.notificationLeadMinutes), id: \.self) { minutes in
                        Text(leadLabel(minutes)).tag(minutes)
                    }
                }
                .disabled(!settings.value.notificationsEnabled)

                Toggle("Play sound", isOn: settings.binding(\.notificationSound))
                    .disabled(!settings.value.notificationsEnabled)
            }

            Section {
                Toggle("Full-screen alert when a meeting starts", isOn: settings.binding(\.fullScreenAlertEnabled))
                Toggle("Only for events with a meeting link", isOn: settings.binding(\.alertsOnlyWithLinks))
            } footer: {
                Text("Ignored events, declined events and all-day events never trigger a reminder or an alert.")
            }

            if settings.value.notificationsEnabled {
                switch appState.notificationAuthorization {
                case .denied:
                    Section {
                        Text("Notifications for NextCall are turned off in System Settings.")
                        Button("Open System Settings") { NSWorkspace.shared.open(SystemSettingsLink.notifications) }
                    }
                case .notDetermined:
                    Section {
                        Button("Allow Notifications") { Task { await appState.requestNotificationAccess() } }
                    }
                case .authorized:
                    EmptyView()
                }
            }
        }
        .formStyle(.grouped)
        .task { await appState.refreshNotificationAuthorization() }
    }

    /// The stored value is always selectable, even if it is not one of the presets.
    private func leadChoices(including value: Int) -> [Int] {
        Self.leadOptions.contains(value) ? Self.leadOptions : (Self.leadOptions + [value]).sorted()
    }

    private func leadLabel(_ minutes: Int) -> String {
        minutes == 0 ? String(localized: "At the start") : String(localized: "\(minutes) min before")
    }
}

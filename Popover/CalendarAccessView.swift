import AppKit
import NextCallCore
import SwiftUI

/// Shown instead of the meeting list (popover and Settings) until calendar access is granted.
struct CalendarAccessView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            switch appState.authorization {
            case .notDetermined:
                Text("NextCall needs access to your calendar to show your meetings.")
                Button("Grant Calendar Access") {
                    Task { await appState.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            case .restricted:
                Text("Calendar access is restricted on this Mac, for example by a profile or Screen Time.")
            case .denied, .granted:
                Text("Calendar access is turned off. Allow NextCall in System Settings to see your meetings.")
                Button("Open System Settings") {
                    NSWorkspace.shared.open(SystemSettingsLink.calendarPrivacy)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

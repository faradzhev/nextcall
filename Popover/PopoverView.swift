import NextCallCore
import SwiftUI

struct PopoverView: View {
    @Environment(AppState.self) private var appState
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            content

            Divider()

            HStack {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("Settings"))
                .accessibilityIdentifier("popover.settings")
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button(action: onQuit) {
                    Image(systemName: "power")
                }
                .accessibilityLabel(Text("Quit NextCall"))
                .accessibilityIdentifier("popover.quit")
                .keyboardShortcut("q", modifiers: .command)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .frame(width: 360)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.authorization {
        case .granted:
            MeetingListView()
        case .notDetermined, .denied, .restricted:
            CalendarAccessView()
        }
    }
}

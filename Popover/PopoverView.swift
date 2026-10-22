import SwiftUI

struct PopoverView: View {
    @Environment(AppState.self) private var appState
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("No upcoming meetings")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)

            Divider()

            HStack {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("Settings"))
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button(action: onQuit) {
                    Image(systemName: "power")
                }
                .accessibilityLabel(Text("Quit NextCall"))
                .keyboardShortcut("q", modifiers: .command)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .frame(width: 360)
    }
}

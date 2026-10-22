import NextCallCore
import SwiftUI

struct PopoverView: View {
    @Environment(AppState.self) private var appState
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.authorization == .granted {
                HeaderView()
                Divider()
            }

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

/// Date, what is next (or running), and the big Join button for the meeting to join.
private struct HeaderView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let timeline = appState.timeline
        VStack(alignment: .leading, spacing: 6) {
            Text(timeline.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(StatusText.summary(for: timeline.status))
                .font(.headline)
                .lineLimit(2)

            if let target = timeline.joinTarget {
                Button {
                    appState.join(target)
                } label: {
                    Label("Join", systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(Text("Join \(StatusText.displayTitle(target))"))
                .accessibilityIdentifier("popover.join")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

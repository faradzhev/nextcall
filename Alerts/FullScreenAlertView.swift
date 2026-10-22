import NextCallCore
import SwiftUI

/// The card shown by the full-screen alert: what is starting, and Join / Dismiss.
struct FullScreenAlertView: View {
    let meeting: Meeting
    let onJoin: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Meeting starting")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(StatusText.displayTitle(meeting))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text((meeting.start..<meeting.end).formatted(Date.IntervalFormatStyle(time: .shortened)))
                .font(.title3)
                .foregroundStyle(.secondary)

            if let link = meeting.link {
                Label(link.provider.displayName, systemImage: "video.fill")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Dismiss", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    .accessibilityIdentifier("alert.dismiss")

                if meeting.link != nil {
                    Button("Join", action: onJoin)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.extraLarge)
                        .accessibilityLabel(Text("Join \(StatusText.displayTitle(meeting))"))
                        .accessibilityIdentifier("alert.join")
                }
            }
            .padding(.top, 6)
        }
        .padding(32)
        .frame(width: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.separator))
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("alert.card")
    }
}

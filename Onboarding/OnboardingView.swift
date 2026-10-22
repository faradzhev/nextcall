import AppKit
import NextCallCore
import SwiftUI

enum OnboardingKey {
    static let completed = "hasCompletedOnboarding"

    /// Where the flag lives. UI tests use a throwaway suite so they never mark the user's real install as onboarded.
    static var store: UserDefaults {
        #if DEBUG
        if UITestSupport.isActive, let suite = UserDefaults(suiteName: UITestSupport.defaultsSuite) { return suite }
        #endif
        return .standard
    }
}

/// First-launch flow: welcome, permissions, then calendars and menu bar display.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(OnboardingKey.completed, store: OnboardingKey.store) private var completed = false
    @State private var step = 0
    let onFinish: () -> Void

    private let lastStep = 2

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: WelcomeStep()
                case 1: AccessStep()
                default: ChooseStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button("Back") { step -= 1 }
                    .opacity(step == 0 ? 0 : 1)
                    .disabled(step == 0)
                    .accessibilityIdentifier("onboarding.back")

                Spacer()
                StepDots(current: step, count: lastStep + 1)
                Spacer()

                if step < lastStep {
                    Button("Continue") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("onboarding.continue")
                } else {
                    Button("Done") {
                        completed = true
                        onFinish()
                    }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("onboarding.done")
                }
            }
            .padding(16)
        }
        .frame(width: 540, height: 540)
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
    }
}

// MARK: Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text("Welcome to NextCall")
                .font(.largeTitle.bold())

            Text("Your next meetings, one click away.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                Feature(symbol: "video.fill", text: "Join any video call in one click or one keystroke.")
                Feature(symbol: "bell.badge", text: "A countdown in the menu bar and a reminder before every meeting.")
                Feature(symbol: "lock.shield", text: "Private: it reads your calendar on this Mac and nothing leaves it.")
            }
            .padding(.top, 8)
        }
        .padding(32)
    }
}

private struct Feature: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

private struct AccessStep: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Allow access")
                .font(.title.bold())

            Text("NextCall needs to read your calendar. Notifications are optional.")
                .foregroundStyle(.secondary)

            PermissionRow(
                symbol: "calendar",
                title: "Calendar",
                status: calendarStatus,
                actionTitle: calendarActionTitle,
                action: calendarAction
            )

            if appState.authorization != .granted {
                Text("Google and Outlook calendars appear here once you add the account in System Settings › Internet Accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            PermissionRow(
                symbol: "bell",
                title: "Notifications",
                status: notificationStatus,
                actionTitle: notificationActionTitle,
                action: notificationAction
            )

            Spacer()
        }
        .padding(32)
        .task { await appState.refreshNotificationAuthorization() }
    }

    // MARK: Calendar

    private var calendarStatus: PermissionRow.Status {
        switch appState.authorization {
        case .granted: .granted
        case .notDetermined: .pending
        case .denied, .restricted: .blocked
        }
    }

    private var calendarActionTitle: LocalizedStringKey? {
        switch appState.authorization {
        case .notDetermined: "Allow Calendar Access"
        case .denied: "Open System Settings"
        case .granted, .restricted: nil
        }
    }

    private func calendarAction() {
        switch appState.authorization {
        case .notDetermined: Task { await appState.requestAccess() }
        case .denied: NSWorkspace.shared.open(SystemSettingsLink.calendarPrivacy)
        case .granted, .restricted: break
        }
    }

    // MARK: Notifications

    private var notificationStatus: PermissionRow.Status {
        switch appState.notificationAuthorization {
        case .authorized: .granted
        case .notDetermined: .pending
        case .denied: .blocked
        }
    }

    private var notificationActionTitle: LocalizedStringKey? {
        switch appState.notificationAuthorization {
        case .notDetermined: "Allow Notifications"
        case .denied: "Open System Settings"
        case .authorized: nil
        }
    }

    private func notificationAction() {
        switch appState.notificationAuthorization {
        case .notDetermined: Task { await appState.requestNotificationAccess() }
        case .denied: NSWorkspace.shared.open(SystemSettingsLink.notifications)
        case .authorized: break
        }
    }
}

private struct PermissionRow: View {
    enum Status { case pending, granted, blocked }

    let symbol: String
    let title: LocalizedStringKey
    let status: Status
    let actionTitle: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                statusLabel
            }

            Spacer()

            if let actionTitle {
                Button(actionTitle, action: action)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .granted:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .pending:
            Text("Not asked yet").foregroundStyle(.secondary)
        case .blocked:
            Label("Turned off", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

private struct ChooseStep: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let settings = appState.settings
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose what to show")
                .font(.title.bold())
                .padding(.horizontal, 32)
                .padding(.top, 32)

            Form {
                if appState.authorization == .granted {
                    if appState.calendarGroups.isEmpty {
                        Text("No calendars found.").foregroundStyle(.secondary)
                    } else {
                        CalendarToggleSections()
                    }
                } else {
                    Text("Calendars will appear here once access is allowed. You can do that later from the menu bar.")
                        .foregroundStyle(.secondary)
                }

                Section("Menu bar") {
                    Picker("Show in menu bar", selection: settings.binding(\.menuBarMode)) {
                        Text("Icon only").tag(MenuBarMode.iconOnly)
                        Text("Countdown").tag(MenuBarMode.countdown)
                        Text("Title and countdown").tag(MenuBarMode.titleAndCountdown)
                    }
                    Toggle("Launch at login", isOn: Binding(
                        get: { appState.launchAtLogin.isOn },
                        set: { appState.launchAtLogin.setEnabled($0) }
                    ))
                }

                Section {
                    Label("NextCall lives in the menu bar. Click the video icon at the top right to see your meetings.", systemImage: "video.badge.checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

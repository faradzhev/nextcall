import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            CalendarsTab()
                .tabItem { Label("Calendars", systemImage: "calendar") }
            NotificationsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
            ProvidersTab()
                .tabItem { Label("Providers", systemImage: "video") }
            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 560)
    }
}

private struct AboutTab: View {
    @Environment(AppState.self) private var appState

    private var version: String {
        let info = Bundle.main
        let short = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        let updater = appState.updater
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text("NextCall")
                .font(.title2.bold())
            Text(version)
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal, 40)

            if updater.isConfigured {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.automaticallyChecks },
                    set: { updater.setAutomaticallyChecks($0) }
                ))
                .toggleStyle(.checkbox)
            } else {
                Text("Updates are not set up in this build.")
                    .foregroundStyle(.secondary)
            }

            Button("Show Welcome Screen") { appState.showOnboarding?() }

            Text("NextCall reads your calendar on this Mac only and has no accounts or analytics. The optional update check is its only network request.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

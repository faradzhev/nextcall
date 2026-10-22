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
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.badge.checkmark")
                .font(.system(size: 40))
                .accessibilityHidden(true)
            Text("NextCall")
                .font(.title2.bold())
            Text("Version \(version)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

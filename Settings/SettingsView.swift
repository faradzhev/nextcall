import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            PlaceholderTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            PlaceholderTab()
                .tabItem { Label("Calendars", systemImage: "calendar") }
            PlaceholderTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
            PlaceholderTab()
                .tabItem { Label("Providers", systemImage: "video") }
            PlaceholderTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 360)
    }
}

private struct PlaceholderTab: View {
    var body: some View {
        Text("This section is coming soon.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

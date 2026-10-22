import NextCallCore
import SwiftUI

struct ProvidersTab: View {
    @Environment(AppState.self) private var appState
    @State private var browsers: [BrowserOption] = []
    @State private var installed: Set<Provider> = []

    var body: some View {
        let settings = appState.settings
        Form {
            Section {
                Picker("Open web links in", selection: settings.binding(\.browserBundleID)) {
                    Text("System default").tag(String?.none)
                    ForEach(browsers) { browser in
                        Text(browser.name).tag(Optional(browser.bundleID))
                    }
                    // Keep a browser that was chosen and later uninstalled visible instead of silently resetting it.
                    if let chosen = settings.value.browserBundleID, !browsers.contains(where: { $0.bundleID == chosen }) {
                        Text(chosen).tag(Optional(chosen))
                    }
                }
            } footer: {
                Text("Used when a provider is set to open in the browser, or its app is not installed.")
            }

            Section("Providers") {
                ForEach(Provider.allCases, id: \.self) { provider in
                    ProviderRow(
                        provider: provider,
                        hasNativeApp: ProviderRegistry.nativeScheme(for: provider) != .none,
                        isInstalled: installed.contains(provider),
                        mode: Binding(
                            get: { settings.value.providerOpenModes[provider.rawValue] ?? .app },
                            set: { mode in
                                settings.update { settings in
                                    // The default is not stored, so an untouched provider stays "app".
                                    settings.providerOpenModes[provider.rawValue] = mode == .app ? nil : mode
                                }
                            }
                        )
                    )
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        let workspace = SystemWorkspace()
        browsers = BrowserCatalog.installed(using: workspace)
        installed = Set(Provider.allCases.filter { ProviderRegistry.isNativeAppInstalled(for: $0, using: workspace) })
    }
}

private struct ProviderRow: View {
    let provider: Provider
    let hasNativeApp: Bool
    let isInstalled: Bool
    @Binding var mode: OpenMode

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            // A menu keeps the row narrow in every language; a provider without an app always shows "Browser".
            Picker(provider.displayName, selection: Binding(
                get: { hasNativeApp ? mode : .browser },
                set: { mode = $0 }
            )) {
                Text("App").tag(OpenMode.app)
                Text("Browser").tag(OpenMode.browser)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .disabled(!hasNativeApp)
            .accessibilityLabel(Text("Open \(provider.displayName) in"))
        }
    }

    private var statusText: String {
        if !hasNativeApp { return String(localized: "Always opens in the browser") }
        return isInstalled ? String(localized: "App installed") : String(localized: "App not installed, uses the browser")
    }
}

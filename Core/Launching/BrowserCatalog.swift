import Foundation

public struct BrowserOption: Hashable, Sendable, Identifiable {
    public let name: String
    public let bundleID: String
    public var id: String { bundleID }
}

public enum BrowserCatalog {
    public static let known: [BrowserOption] = [
        BrowserOption(name: "Safari", bundleID: "com.apple.Safari"),
        BrowserOption(name: "Google Chrome", bundleID: "com.google.Chrome"),
        BrowserOption(name: "Arc", bundleID: "company.thebrowser.Browser"),
        BrowserOption(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac"),
        BrowserOption(name: "Firefox", bundleID: "org.mozilla.firefox"),
    ]

    /// The known browsers that are installed.
    @MainActor
    public static func installed(using workspace: any WorkspaceControlling) -> [BrowserOption] {
        known.filter { workspace.applicationURL(forBundleIdentifier: $0.bundleID) != nil }
    }
}

extension NativeScheme {
    /// A URL with this scheme, used only to ask the system whether an app handles it.
    public var probeURL: URL? {
        switch self {
        case .none: nil
        case .zoom: URL(string: "zoommtg://zoom.us")
        case .teams: URL(string: "msteams:/")
        case .webex: URL(string: "webex://")
        case .slack: URL(string: "slack://")
        case .discord: URL(string: "discord://")
        case .jitsi: URL(string: "jitsi-meet://")
        }
    }
}

extension ProviderRegistry {
    /// The native scheme of a provider, or `.none` when it only has a web link.
    public static func nativeScheme(for provider: Provider) -> NativeScheme {
        rules.first { $0.provider == provider && $0.native != .none }?.native ?? .none
    }

    /// Whether the provider's native app is installed. Providers without one report false.
    @MainActor
    public static func isNativeAppInstalled(for provider: Provider, using workspace: any WorkspaceControlling) -> Bool {
        guard let probe = nativeScheme(for: provider).probeURL else { return false }
        return workspace.applicationURL(toOpen: probe) != nil
    }
}

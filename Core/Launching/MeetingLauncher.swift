import AppKit

public enum OpenMode: String, Codable, CaseIterable, Sendable {
    /// Use the provider's native app when it is installed.
    case app
    case browser
}

public struct LaunchPreferences: Sendable, Equatable {
    public var modes: [Provider: OpenMode]
    /// Bundle identifier of the browser to use; nil means the system default browser.
    public var browserBundleID: String?

    public init(modes: [Provider: OpenMode] = [:], browserBundleID: String? = nil) {
        self.modes = modes
        self.browserBundleID = browserBundleID
    }

    public func mode(for provider: Provider) -> OpenMode { modes[provider] ?? .app }
}

public enum LaunchResult: Sendable, Equatable {
    case nativeApp
    case browser(bundleID: String?)
    case failed(String)
}

/// The slice of `NSWorkspace` the launcher needs, so it can be tested without opening anything.
@MainActor
public protocol WorkspaceControlling {
    /// The app registered to handle `url`'s scheme, if any.
    func applicationURL(toOpen url: URL) -> URL?
    func applicationURL(forBundleIdentifier bundleID: String) -> URL?
    /// Opens `url`, with `applicationURL` if given, else with the default handler.
    func open(_ url: URL, withApplicationAt applicationURL: URL?) async throws
}

@MainActor
public struct SystemWorkspace: WorkspaceControlling {
    public init() {}

    public func applicationURL(toOpen url: URL) -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: url)
    }

    public func applicationURL(forBundleIdentifier bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    public func open(_ url: URL, withApplicationAt applicationURL: URL?) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let applicationURL {
            _ = try await NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration)
        } else {
            _ = try await NSWorkspace.shared.open(url, configuration: configuration)
        }
    }
}

/// Opens a meeting link: the native app when the provider is set to "app" and that app is installed,
/// otherwise the chosen browser, otherwise the system default browser.
@MainActor
public final class MeetingLauncher {
    private let workspace: any WorkspaceControlling

    public init(workspace: any WorkspaceControlling = SystemWorkspace()) {
        self.workspace = workspace
    }

    @discardableResult
    public func join(_ link: MeetingLink, preferences: LaunchPreferences) async -> LaunchResult {
        if preferences.mode(for: link.provider) == .app,
           let native = link.nativeURL,
           workspace.applicationURL(toOpen: native) != nil {
            do {
                try await workspace.open(native, withApplicationAt: nil)
                return .nativeApp
            } catch {
                Log.launching.error("Native open failed, falling back to browser: \(error.localizedDescription, privacy: .public)")
            }
        }
        return await openInBrowser(link.url, preferences: preferences)
    }

    private func openInBrowser(_ url: URL, preferences: LaunchPreferences) async -> LaunchResult {
        if let bundleID = preferences.browserBundleID,
           let browser = workspace.applicationURL(forBundleIdentifier: bundleID) {
            do {
                try await workspace.open(url, withApplicationAt: browser)
                return .browser(bundleID: bundleID)
            } catch {
                Log.launching.error("Chosen browser failed, using default: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try await workspace.open(url, withApplicationAt: nil)
            return .browser(bundleID: nil)
        } catch {
            Log.launching.error("Could not open meeting link: \(error.localizedDescription, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }
}

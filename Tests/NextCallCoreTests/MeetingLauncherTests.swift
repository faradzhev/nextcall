import Foundation
import Testing
@testable import NextCallCore

@MainActor
final class FakeWorkspace: WorkspaceControlling {
    var handledSchemes: Set<String> = []
    var installedBundles: [String: URL] = [:]
    var failingTargets: Set<String> = []
    private(set) var opened: [(url: URL, app: URL?)] = []

    func applicationURL(toOpen url: URL) -> URL? {
        guard let scheme = url.scheme, handledSchemes.contains(scheme) else { return nil }
        return URL(fileURLWithPath: "/Applications/Native.app")
    }

    func applicationURL(forBundleIdentifier bundleID: String) -> URL? { installedBundles[bundleID] }

    func open(_ url: URL, withApplicationAt applicationURL: URL?) async throws {
        opened.append((url, applicationURL))
        if failingTargets.contains(url.absoluteString) || (applicationURL.map { failingTargets.contains($0.path) } ?? false) {
            throw CocoaError(.fileNoSuchFile)
        }
    }
}

@MainActor
@Suite struct MeetingLauncherTests {
    private let zoom = MeetingLink(
        provider: .zoom,
        url: URL(string: "https://zoom.us/j/123456789?pwd=abc")!,
        nativeURL: URL(string: "zoommtg://zoom.us/join?confno=123456789&pwd=abc")
    )
    private let meet = MeetingLink(provider: .googleMeet, url: URL(string: "https://meet.google.com/abc-defg-hij")!, nativeURL: nil)
    private let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")

    @Test func opensNativeAppWhenInstalledAndModeIsApp() async {
        let workspace = FakeWorkspace()
        workspace.handledSchemes = ["zoommtg"]
        let result = await MeetingLauncher(workspace: workspace).join(zoom, preferences: LaunchPreferences())
        #expect(result == .nativeApp)
        #expect(workspace.opened.map(\.url) == [zoom.nativeURL!])
        #expect(workspace.opened[0].app == nil)
    }

    @Test func fallsBackToTheBrowserWhenTheAppIsNotInstalled() async {
        let workspace = FakeWorkspace()
        let result = await MeetingLauncher(workspace: workspace).join(zoom, preferences: LaunchPreferences())
        #expect(result == .browser(bundleID: nil))
        #expect(workspace.opened.map(\.url) == [zoom.url])
    }

    @Test func browserModeIgnoresAnInstalledApp() async {
        let workspace = FakeWorkspace()
        workspace.handledSchemes = ["zoommtg"]
        let prefs = LaunchPreferences(modes: [.zoom: .browser])
        let result = await MeetingLauncher(workspace: workspace).join(zoom, preferences: prefs)
        #expect(result == .browser(bundleID: nil))
        #expect(workspace.opened.map(\.url) == [zoom.url])
    }

    @Test func modeOfOneProviderDoesNotAffectAnother() async {
        let workspace = FakeWorkspace()
        workspace.handledSchemes = ["zoommtg"]
        let prefs = LaunchPreferences(modes: [.googleMeet: .browser])
        #expect(await MeetingLauncher(workspace: workspace).join(zoom, preferences: prefs) == .nativeApp)
    }

    @Test func linksWithoutANativeURLOpenInTheBrowser() async {
        let workspace = FakeWorkspace()
        let result = await MeetingLauncher(workspace: workspace).join(meet, preferences: LaunchPreferences())
        #expect(result == .browser(bundleID: nil))
    }

    @Test func usesTheChosenBrowser() async {
        let workspace = FakeWorkspace()
        workspace.installedBundles["com.google.Chrome"] = chrome
        let prefs = LaunchPreferences(browserBundleID: "com.google.Chrome")
        let result = await MeetingLauncher(workspace: workspace).join(meet, preferences: prefs)
        #expect(result == .browser(bundleID: "com.google.Chrome"))
        #expect(workspace.opened[0].app == chrome)
    }

    @Test func fallsBackToTheDefaultBrowserWhenTheChosenOneIsGone() async {
        let workspace = FakeWorkspace()
        let prefs = LaunchPreferences(browserBundleID: "com.example.Removed")
        let result = await MeetingLauncher(workspace: workspace).join(meet, preferences: prefs)
        #expect(result == .browser(bundleID: nil))
        #expect(workspace.opened[0].app == nil)
    }

    @Test func fallsBackWhenTheChosenBrowserFailsToOpen() async {
        let workspace = FakeWorkspace()
        workspace.installedBundles["com.google.Chrome"] = chrome
        workspace.failingTargets = [chrome.path]
        let prefs = LaunchPreferences(browserBundleID: "com.google.Chrome")
        let result = await MeetingLauncher(workspace: workspace).join(meet, preferences: prefs)
        #expect(result == .browser(bundleID: nil))
        #expect(workspace.opened.count == 2)
    }

    @Test func fallsBackToTheBrowserWhenTheNativeOpenFails() async {
        let workspace = FakeWorkspace()
        workspace.handledSchemes = ["zoommtg"]
        workspace.failingTargets = [zoom.nativeURL!.absoluteString]
        let result = await MeetingLauncher(workspace: workspace).join(zoom, preferences: LaunchPreferences())
        #expect(result == .browser(bundleID: nil))
        #expect(workspace.opened.map(\.url) == [zoom.nativeURL!, zoom.url])
    }

    @Test func reportsFailureWhenNothingCanOpenTheLink() async {
        let workspace = FakeWorkspace()
        workspace.failingTargets = [meet.url.absoluteString]
        let result = await MeetingLauncher(workspace: workspace).join(meet, preferences: LaunchPreferences())
        guard case .failed = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
    }

    @Test func settingsProduceLaunchPreferences() {
        var settings = AppSettings()
        settings.providerOpenModes = ["zoom": .browser, "notAProvider": .app]
        settings.browserBundleID = "com.apple.Safari"
        let prefs = settings.launchPreferences
        #expect(prefs.mode(for: .zoom) == .browser)
        #expect(prefs.mode(for: .teams) == .app)
        #expect(prefs.modes.count == 1)
        #expect(prefs.browserBundleID == "com.apple.Safari")
    }
}

final class FakeLoginService: LoginItemService, @unchecked Sendable {
    private let lock = NSLock()
    private var current: LoginItemStatus
    var failure: Error?
    var statusAfterRegister: LoginItemStatus = .enabled
    private(set) var openedSettings = false

    init(_ status: LoginItemStatus = .notRegistered) { current = status }

    var status: LoginItemStatus { lock.withLock { current } }

    func register() throws {
        if let failure { throw failure }
        lock.withLock { current = statusAfterRegister }
    }

    func unregister() throws {
        if let failure { throw failure }
        lock.withLock { current = .notRegistered }
    }

    func openSystemSettings() { openedSettings = true }
}

@MainActor
@Suite struct LaunchAtLoginTests {
    @Test func reflectsTheSystemStatus() {
        #expect(LaunchAtLogin(service: FakeLoginService(.enabled)).isOn)
        #expect(!LaunchAtLogin(service: FakeLoginService(.notRegistered)).isOn)
        #expect(!LaunchAtLogin(service: FakeLoginService(.notFound)).isOn)
    }

    @Test func enablingAndDisablingRoundTrips() {
        let login = LaunchAtLogin(service: FakeLoginService())
        login.setEnabled(true)
        #expect(login.status == .enabled)
        login.setEnabled(false)
        #expect(login.status == .notRegistered)
        #expect(login.lastError == nil)
    }

    @Test func pendingApprovalCountsAsOnAndIsVisible() {
        let service = FakeLoginService()
        service.statusAfterRegister = .requiresApproval
        let login = LaunchAtLogin(service: service)
        login.setEnabled(true)
        #expect(login.status == .requiresApproval)
        #expect(login.isOn)
    }

    @Test func failuresAreReportedAndStatusIsReread() {
        let service = FakeLoginService()
        service.failure = CocoaError(.fileWriteNoPermission)
        let login = LaunchAtLogin(service: service)
        login.setEnabled(true)
        #expect(login.lastError != nil)
        #expect(login.status == .notRegistered)
    }

    @Test func opensSystemSettingsOnRequest() {
        let service = FakeLoginService(.requiresApproval)
        LaunchAtLogin(service: service).openSystemSettings()
        #expect(service.openedSettings)
    }
}

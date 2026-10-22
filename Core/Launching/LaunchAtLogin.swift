import Foundation
import Observation
import ServiceManagement

public enum LoginItemStatus: Sendable, Equatable {
    case notRegistered
    case enabled
    /// Registered, but the user still has to allow it in System Settings > Login Items.
    case requiresApproval
    case notFound
}

public protocol LoginItemService: Sendable {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

public struct SystemLoginItemService: LoginItemService {
    public init() {}

    public var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        default: .notRegistered
        }
    }

    public func register() throws { try SMAppService.mainApp.register() }
    public func unregister() throws { try SMAppService.mainApp.unregister() }
    public func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// Launch-at-login toggle backed by `SMAppService.mainApp`. The system owns the state, so it is
/// re-read after every change rather than stored in settings.
@MainActor
@Observable
public final class LaunchAtLogin {
    public private(set) var status: LoginItemStatus
    public private(set) var lastError: String?

    @ObservationIgnored private let service: any LoginItemService

    public init(service: any LoginItemService = SystemLoginItemService()) {
        self.service = service
        status = service.status
    }

    /// On while registered, including when the system still waits for the user's approval.
    public var isOn: Bool { status == .enabled || status == .requiresApproval }

    public func refresh() {
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            lastError = error.localizedDescription
            Log.app.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    public func openSystemSettings() {
        service.openSystemSettings()
    }
}

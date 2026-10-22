import Foundation
import Observation

#if DIRECT_DISTRIBUTION
import Sparkle

/// Sparkle 2 updater (direct distribution only). It starts only when the build carries a feed URL
/// and a public EdDSA key, so development builds never contact the network.
@MainActor
@Observable
final class UpdaterModel {
    private(set) var isConfigured = false
    private(set) var canCheckForUpdates = false
    private(set) var automaticallyChecks = false

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init(start: Bool = true) {
        func infoValue(_ key: String) -> String {
            (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        }
        guard start, !infoValue("SUFeedURL").isEmpty, !infoValue("SUPublicEDKey").isEmpty else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        isConfigured = true
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.canCheckForUpdates = value }
        }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecks = controller?.updater.automaticallyChecksForUpdates ?? false
    }
}
#else
/// Mac App Store builds update through the store, so there is nothing to configure.
@MainActor
@Observable
final class UpdaterModel {
    let isConfigured = false
    let canCheckForUpdates = false
    let automaticallyChecks = false

    init(start: Bool = true) {}
    func checkForUpdates() {}
    func setAutomaticallyChecks(_ enabled: Bool) {}
}
#endif

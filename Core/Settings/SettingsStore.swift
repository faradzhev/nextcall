import Foundation
import Observation

/// Persists `AppSettings` as a single JSON blob in UserDefaults.
@MainActor
@Observable
public final class SettingsStore {
    public static let key = "settings.v1"

    public private(set) var value: AppSettings

    /// Called after a change with the old and new values.
    @ObservationIgnored public var onChange: (@MainActor (AppSettings, AppSettings) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                value = try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                Log.app.error("Settings blob unreadable, using defaults: \(error.localizedDescription, privacy: .public)")
                value = AppSettings()
            }
        } else {
            value = AppSettings()
        }
        Self.clamp(&value)
    }

    public func update(_ mutate: (inout AppSettings) -> Void) {
        let old = value
        var new = old
        mutate(&new)
        Self.clamp(&new)
        guard new != old else { return }
        value = new
        do {
            defaults.set(try JSONEncoder().encode(new), forKey: Self.key)
        } catch {
            Log.app.error("Could not save settings: \(error.localizedDescription, privacy: .public)")
        }
        onChange?(old, new)
    }

    private static func clamp(_ settings: inout AppSettings) {
        settings.daysAhead = min(max(settings.daysAhead, 1), CalendarService.maxDays)
        let range = AppSettings.titleLengthRange
        settings.menuBarTitleLength = min(max(settings.menuBarTitleLength, range.lowerBound), range.upperBound)
    }
}

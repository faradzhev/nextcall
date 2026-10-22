import Foundation
import Testing
@testable import NextCallCore

@MainActor
@Suite struct SettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "NextCallTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func startsWithDefaults() {
        let store = SettingsStore(defaults: makeDefaults())
        #expect(store.value == AppSettings())
        #expect(store.value.hideDeclined)
        #expect(store.value.daysAhead == 2)
    }

    @Test func persistsAcrossInstances() {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).update {
            $0.daysAhead = 5
            $0.disabledCalendarIDs = ["a", "b"]
        }
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.value.daysAhead == 5)
        #expect(reloaded.value.disabledCalendarIDs == ["a", "b"])
    }

    @Test func corruptBlobFallsBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: SettingsStore.key)
        #expect(SettingsStore(defaults: defaults).value == AppSettings())
    }

    @Test func olderBlobWithMissingKeysKeepsDefaultsForThem() {
        let defaults = makeDefaults()
        defaults.set(Data(#"{"daysAhead": 4}"#.utf8), forKey: SettingsStore.key)
        let store = SettingsStore(defaults: defaults)
        #expect(store.value.daysAhead == 4)
        #expect(store.value.hideDeclined)
        #expect(store.value.pastEvents == .dimmed)
    }

    @Test func daysAheadIsClamped() {
        let store = SettingsStore(defaults: makeDefaults())
        store.update { $0.daysAhead = 30 }
        #expect(store.value.daysAhead == CalendarService.maxDays)
        store.update { $0.daysAhead = 0 }
        #expect(store.value.daysAhead == 1)
    }

    @Test func outOfRangeStoredValueIsClampedOnLoad() {
        let defaults = makeDefaults()
        defaults.set(Data(#"{"daysAhead": 99}"#.utf8), forKey: SettingsStore.key)
        #expect(SettingsStore(defaults: defaults).value.daysAhead == CalendarService.maxDays)
    }

    @Test func onChangeFiresOnlyForRealChanges() {
        let store = SettingsStore(defaults: makeDefaults())
        var calls: [(AppSettings, AppSettings)] = []
        store.onChange = { calls.append(($0, $1)) }
        store.update { $0.showAllDay = false } // already false: no change
        #expect(calls.isEmpty)
        store.update { $0.showAllDay = true }
        #expect(calls.count == 1)
        #expect(calls[0].0.showAllDay == false)
        #expect(calls[0].1.showAllDay == true)
    }
}

@MainActor
@Suite struct MenuBarSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "NextCallTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsAreCountdownTwentyCharsAndAppMode() {
        let settings = AppSettings()
        #expect(settings.menuBarMode == .countdown)
        #expect(settings.menuBarTitleLength == 20)
        #expect(settings.providerOpenModes.isEmpty)
        #expect(settings.browserBundleID == nil)
    }

    @Test func titleLengthIsClampedToItsRange() {
        let store = SettingsStore(defaults: makeDefaults())
        store.update { $0.menuBarTitleLength = 500 }
        #expect(store.value.menuBarTitleLength == 40)
        store.update { $0.menuBarTitleLength = 1 }
        #expect(store.value.menuBarTitleLength == 5)
    }

    @Test func newFieldsSurviveARoundTripAndOldBlobsStillLoad() throws {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).update {
            $0.menuBarMode = .titleAndCountdown
            $0.providerOpenModes = ["zoom": .browser]
            $0.browserBundleID = "org.mozilla.firefox"
        }
        let reloaded = SettingsStore(defaults: defaults).value
        #expect(reloaded.menuBarMode == .titleAndCountdown)
        #expect(reloaded.providerOpenModes == ["zoom": .browser])
        #expect(reloaded.browserBundleID == "org.mozilla.firefox")

        defaults.set(Data(#"{"daysAhead": 3, "hideDeclined": false}"#.utf8), forKey: SettingsStore.key)
        let old = SettingsStore(defaults: defaults).value
        #expect(old.daysAhead == 3)
        #expect(old.menuBarMode == .countdown)
    }
}

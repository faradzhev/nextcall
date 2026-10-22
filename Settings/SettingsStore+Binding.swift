import NextCallCore
import SwiftUI

extension SettingsStore {
    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.value[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    func calendarEnabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { !self.value.disabledCalendarIDs.contains(id) },
            set: { enabled in
                self.update { settings in
                    if enabled {
                        settings.disabledCalendarIDs.remove(id)
                    } else {
                        settings.disabledCalendarIDs.insert(id)
                    }
                }
            }
        )
    }
}

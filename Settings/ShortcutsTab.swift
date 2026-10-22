import KeyboardShortcuts
import SwiftUI

struct ShortcutsTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Open popover", name: .openPopover)
                KeyboardShortcuts.Recorder("Join next meeting", name: .joinNext)
                KeyboardShortcuts.Recorder("Dismiss alert", name: .dismissAlert)
            } footer: {
                Text("These work from any app. Click a field and press the keys you want; press Delete to clear it.")
            }
        }
        .formStyle(.grouped)
    }
}

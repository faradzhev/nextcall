import SwiftUI

@main
struct NextCallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    /// The app's whole UI is the status item, popover and the settings window owned by `AppDelegate`.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

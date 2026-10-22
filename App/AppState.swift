import Observation

/// Single source of truth for the UI. Views read from here and never touch EventKit directly.
@MainActor
@Observable
final class AppState {
    /// Text shown next to the menu bar icon; `nil` means icon only.
    var menuBarTitle: String?
}

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openPopover = Self("openPopover", default: .init(.n, modifiers: [.control, .option]))
    static let joinNext = Self("joinNext", default: .init(.j, modifiers: [.control, .option]))
    static let dismissAlert = Self("dismissAlert")
}

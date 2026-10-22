import AppKit
import NextCallCore
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let appState: AppState
    private let openSettings: @MainActor () -> Void

    init(appState: AppState, openSettings: @escaping @MainActor () -> Void) {
        self.appState = appState
        self.openSettings = openSettings
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let content = PopoverView(
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettings()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        .environment(appState)

        let hosting = NSHostingController(rootView: content)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient

        appState.requestClosePopover = { [weak self] in self?.popover.performClose(nil) }
        observe()
    }

    // MARK: Status item appearance

    /// Re-renders whenever the observed state (timeline, menu bar settings) changes.
    private func observe() {
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            // onChange fires before the new value lands, so re-read on the next main-actor turn.
            Task { @MainActor in self?.observe() }
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let settings = appState.settings.value
        let status = appState.timeline.status
        let display = MenuBarDisplay.make(
            status: status,
            mode: settings.menuBarMode,
            titleLength: settings.menuBarTitleLength
        )
        let text = StatusText.menuBarText(display)

        let symbol = display.isImminent ? "video.fill" : "video.badge.checkmark"
        let label = String(localized: "NextCall")
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = text == nil ? .imageOnly : .imageLeft

        if let text {
            let color: NSColor = display.isImminent ? .controlAccentColor : .labelColor
            button.attributedTitle = NSAttributedString(
                string: " " + text,
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                ]
            )
        } else {
            button.title = ""
        }
        button.contentTintColor = display.isImminent ? .controlAccentColor : nil
        button.setAccessibilityLabel("\(label), \(StatusText.summary(for: status))")
    }

    // MARK: Clicks

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isSecondary = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isSecondary {
            showMenu()
        } else {
            togglePopover()
        }
    }

    func showPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
        }
    }

    private func showMenu() {
        popover.performClose(nil)

        let menu = NSMenu()
        menu.autoenablesItems = false

        let join = NSMenuItem(title: String(localized: "Join Next Meeting"), action: #selector(joinNext), keyEquivalent: "")
        join.target = self
        join.isEnabled = appState.timeline.joinTarget != nil
        menu.addItem(join)
        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: String(localized: "Settings…"),
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(
            title: String(localized: "Quit NextCall"),
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        // Attach the menu only for this click so left click keeps toggling the popover.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func joinNext() { appState.joinNext() }
    @objc private func openSettingsFromMenu() { openSettings() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
}

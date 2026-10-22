import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let openSettings: @MainActor () -> Void

    init(appState: AppState, openSettings: @escaping @MainActor () -> Void) {
        self.openSettings = openSettings
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "video.badge.checkmark",
                accessibilityDescription: String(localized: "NextCall")
            )
            button.setAccessibilityLabel(String(localized: "NextCall"))
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
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isSecondary = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isSecondary {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
        }
    }

    private func showMenu() {
        popover.performClose(nil)

        let menu = NSMenu()
        menu.autoenablesItems = false

        let join = NSMenuItem(title: String(localized: "Join Next Meeting"), action: nil, keyEquivalent: "")
        join.isEnabled = false
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

    @objc private func openSettingsFromMenu() { openSettings() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
}

import AppKit
import NextCallCore
import SwiftUI

/// A borderless panel that can take key focus, so Esc and Return reach the alert.
private final class AlertPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// Shows the full-screen "meeting starting" alert (FR-10): a card above everything, on every display
/// and every Space, dismissed with Esc, a click, the global hotkey or after five minutes.
@MainActor
final class AlertPresenter {
    static let autoDismiss: Duration = .seconds(5 * 60)

    private var panels: [NSPanel] = []
    private var dismissTask: Task<Void, Never>?

    var isShowing: Bool { !panels.isEmpty }

    func show(_ meeting: Meeting, onJoin: @escaping @MainActor () -> Void) {
        dismiss()

        let mouse = NSEvent.mouseLocation
        let primary = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        for screen in NSScreen.screens {
            let panel = makePanel(for: meeting, on: screen, onJoin: onJoin)
            panels.append(panel)
            panel.orderFrontRegardless()
            if screen == primary { panel.makeKey() }
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autoDismiss)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        for panel in panels { panel.close() }
        panels.removeAll()
    }

    private func makePanel(for meeting: Meeting, on screen: NSScreen, onJoin: @escaping @MainActor () -> Void) -> AlertPanel {
        let view = FullScreenAlertView(
            meeting: meeting,
            onJoin: { [weak self] in
                self?.dismiss()
                onJoin()
            },
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = AlertPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.onCancel = { [weak self] in self?.dismiss() }
        panel.setFrameOrigin(NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        ))
        return panel
    }
}

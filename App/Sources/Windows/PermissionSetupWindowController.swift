import AppKit
import SwiftUI

private final class PermissionSetupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PermissionSetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func runModal() -> Bool {
        let contentView = PermissionSetupView(
            onContinue: { [weak self] in self?.finish(with: .OK) },
            onNotNow: { [weak self] in self?.finish(with: .cancel) }
        )
        let hostingView = NSHostingView(rootView: contentView)
        let window = PermissionSetupWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.moveToActiveSpace]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentView = hostingView
        window.delegate = self
        window.center()

        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        let response = NSApp.runModal(for: window)
        window.orderOut(nil)
        window.delegate = nil
        window.close()
        self.window = nil
        return response == .OK
    }

    func windowWillClose(_ notification: Notification) {
        finish(with: .cancel)
    }

    private func finish(with response: NSApplication.ModalResponse) {
        guard let window else { return }
        if NSApp.modalWindow === window {
            NSApp.stopModal(withCode: response)
        }
    }
}

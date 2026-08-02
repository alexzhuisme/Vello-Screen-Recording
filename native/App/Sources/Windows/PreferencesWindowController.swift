import AppKit
import SwiftUI
import VelloCore

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settings: VelloCore.Settings

    var onClose: (() -> Void)?

    init(settings: VelloCore.Settings) {
        self.settings = settings
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hostingController = NSHostingController(rootView: PreferencesView(settings: settings))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Vello Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window = nil
        onClose?()
    }
}

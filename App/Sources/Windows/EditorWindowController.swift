import AppKit
import SwiftUI
import VelloCore

@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    let model: EditorModel
    private var window: NSWindow?

    var onClose: ((EditorWindowController) -> Void)?

    init(model: EditorModel) {
        self.model = model
        super.init()
        model.onClose = { [weak self] in self?.close() }
    }

    func show() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = model.title
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentMinSize = CGSize(width: 520, height: 420)
        window.contentView = NSHostingView(rootView: EditorView(model: model))
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
        model.pause()
        model.cancelExport()
        window?.delegate = nil
        window = nil
        onClose?(self)
    }
}

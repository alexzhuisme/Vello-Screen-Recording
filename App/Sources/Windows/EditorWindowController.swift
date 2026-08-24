import AppKit
import SwiftUI
import VelloCore

@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    let model: EditorModel
    private var window: NSWindow?
    private var keyMonitor: Any?

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
        installKeyboardControls(for: window)
        NSApp.activate()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyboardControls()
        model.pause()
        model.cancelExport()
        window?.delegate = nil
        window = nil
        onClose?(self)
    }

    private func installKeyboardControls(for window: NSWindow) {
        removeKeyboardControls()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            var handled = false
            MainActor.assumeIsolated {
                guard let self,
                      let window,
                      window.isKeyWindow,
                      self.model.exportJob == nil,
                      !(window.firstResponder is NSTextView),
                      !event.modifierFlags.contains(.command),
                      !event.modifierFlags.contains(.control)
                else { return }

                switch event.keyCode {
                case 49: // Space
                    if !event.isARepeat {
                        self.model.togglePlayback()
                    }
                    handled = true
                case 123: // Left Arrow
                    self.model.seekBy(event.modifierFlags.contains(.option) ? -5 : -1)
                    handled = true
                case 124: // Right Arrow
                    self.model.seekBy(event.modifierFlags.contains(.option) ? 5 : 1)
                    handled = true
                case 34 where !event.isARepeat: // I
                    self.model.setTrimStartAtPlayhead()
                    handled = true
                case 31 where !event.isARepeat: // O
                    self.model.setTrimEndAtPlayhead()
                    handled = true
                default:
                    break
                }
            }
            return handled ? nil : event
        }
    }

    private func removeKeyboardControls() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

import AppKit
import SwiftUI
import VelloCapture
import VelloCore

/// Borderless overlay panel. Non-activating so showing the cropper does not steal
/// focus from whatever the user is about to record.
final class CropperPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class CropperWindowController {
    let model: CropperModel

    private var panels: [CGDirectDisplayID: CropperPanel] = [:]
    private var screenChangeObserver: NSObjectProtocol?

    init(model: CropperModel) {
        self.model = model
    }

    isolated deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    var isVisible: Bool { !panels.isEmpty }

    func show(displays: [CaptureDisplay], preferredDisplayID: CGDirectDisplayID?) {
        model.prepare(displays: displays, preferredDisplayID: preferredDisplayID)
        model.refreshAudioDevices()

        rebuildPanels(for: displays)
        observeScreenChanges()

        if let activeID = model.activeDisplayID, let panel = panels[activeID] {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func close() {
        for panel in panels.values {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panels.removeAll()

        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
            self.screenChangeObserver = nil
        }
    }

    /// While recording the overlay stays on screen to show the capture border,
    /// but must not intercept clicks meant for the app being recorded.
    func setRecording(_ isRecording: Bool) {
        model.isRecording = isRecording
        for panel in panels.values {
            panel.ignoresMouseEvents = isRecording
            if isRecording {
                panel.resignKey()
            }
        }
    }

    // MARK: - Panels

    private func rebuildPanels(for displays: [CaptureDisplay]) {
        let wanted = Set(displays.map(\.id))

        for (id, panel) in panels where !wanted.contains(id) {
            panel.orderOut(nil)
            panel.contentView = nil
            panels[id] = nil
        }

        for display in displays {
            if let existing = panels[display.id] {
                existing.setFrame(display.frame, display: true)
                continue
            }
            panels[display.id] = makePanel(for: display)
        }
    }

    private func makePanel(for display: CaptureDisplay) -> CropperPanel {
        let panel = CropperPanel(
            contentRect: display.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.onCancel = { [weak self] in self?.model.onCancel?() }

        let hostingView = NSHostingView(rootView: CropperOverlayView(display: display, model: model))
        hostingView.frame = CGRect(origin: .zero, size: display.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        panel.setFrame(display.frame, display: true)
        panel.orderFrontRegardless()
        return panel
    }

    private func observeScreenChanges() {
        guard screenChangeObserver == nil else { return }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, !self.model.isRecording else { return }
                Task { await self.refreshDisplays() }
            }
        }
    }

    private func refreshDisplays() async {
        guard let displays = try? await CaptureDevices.displays() else { return }
        model.displays = displays
        rebuildPanels(for: displays)
    }
}

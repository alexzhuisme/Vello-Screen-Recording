import AppKit
import SwiftUI
import VelloCapture
import VelloCore
import VelloUI

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
    private struct WebcamDragState {
        let displayID: CGDirectDisplayID
        let captureFrame: CGRect
    }

    let model: CropperModel

    private var panels: [CGDirectDisplayID: CropperPanel] = [:]
    private var screenChangeObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var mouseMonitor: Any?
    private var webcamDragState: WebcamDragState?

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
        model.refreshVideoDevices()
        model.refreshMicrophoneMonitoring()

        rebuildPanels(for: displays)
        observeScreenChanges()
        installEventMonitors()

        if let activeID = model.activeDisplayID, let panel = panels[activeID] {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func close() {
        model.cancelCountdown()
        model.stopMicrophoneMonitoring()
        removeEventMonitors()

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

    /// While recording a region the overlay stays on screen to show the capture
    /// border, but must not intercept clicks meant for the app being recorded.
    /// Window recordings close the overlay entirely — a fixed border would lie
    /// as the window moves.
    func setRecording(_ isRecording: Bool, hidesOverlay: Bool = false) {
        model.isRecording = isRecording

        if hidesOverlay {
            close()
            return
        }

        for panel in panels.values {
            panel.ignoresMouseEvents = isRecording
            if isRecording {
                panel.resignKey()
            }
        }

        if isRecording {
            removeEventMonitors()
        } else if isVisible {
            installEventMonitors()
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
        panel.onCancel = { [weak self] in self?.model.handleCancel() }

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
                self.model.cancelCountdown()
                Task { await self.refreshDisplays() }
            }
        }
    }

    private func refreshDisplays() async {
        guard let displays = try? await CaptureDevices.displays() else { return }
        model.displays = displays
        rebuildPanels(for: displays)
        if model.selectionMode == .window {
            await model.refreshWindows()
        }
    }

    // MARK: - Keyboard / mouse

    private func installEventMonitors() {
        removeEventMonitors()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            var consume = false
            MainActor.assumeIsolated {
                guard let self, self.isVisible, !self.model.isRecording else { return }
                switch event.keyCode {
                case 49 where !event.isARepeat && !self.model.isCountingDown:
                    // Space toggles region ↔ window, matching macOS screenshot UX.
                    self.model.toggleSelectionMode()
                    consume = true
                case 53: // Escape
                    self.model.handleCancel()
                    consume = true
                default:
                    break
                }
            }
            return consume ? nil : event
        }

        // After other screenshot tools steal focus, the cropper panel may no longer
        // be key — local Escape stops working. A global monitor still cancels.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, !self.model.isRecording else { return }
                if event.keyCode == 53 {
                    self.model.handleCancel()
                }
            }
        }

        // Keep hover accurate when the mouse moves across displays without
        // relying solely on SwiftUI's per-view continuous hover.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            var consume = false
            MainActor.assumeIsolated {
                guard let self,
                      self.isVisible,
                      !self.model.isRecording,
                      !self.model.isCountingDown
                else { return }

                // Handle the webcam bubble before SwiftUI receives the event. The
                // full selection surface also owns a drag gesture, so resolving
                // this at the panel boundary prevents it from stealing camera
                // movement on large or full-screen selections.
                if self.handleWebcamDragEvent(event) {
                    consume = true
                    return
                }

                // Reclaim key status so Escape / Space keep working after other
                // overlay apps have been used.
                if let activeID = self.model.activeDisplayID,
                   let panel = self.panels[activeID],
                   !panel.isKeyWindow {
                    panel.makeKey()
                }

                guard self.model.selectionMode == .window,
                      self.model.selectedWindow == nil
                else { return }

                let location = NSEvent.mouseLocation
                guard let display = self.model.displays.first(where: { $0.frame.contains(location) })
                else { return }

                let window = self.captureWindowUnderCursor(at: location)
                self.model.updateHover(window: window, on: display)
            }
            return consume ? nil : event
        }
    }

    private func handleWebcamDragEvent(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseDown:
            guard webcamDragState == nil,
                  model.settings.webcamEnabled,
                  let context = webcamDragContext(for: event),
                  context.bubbleFrame.insetBy(dx: -10, dy: -10).contains(context.location)
            else { return false }

            webcamDragState = WebcamDragState(
                displayID: context.display.id,
                captureFrame: context.captureFrame
            )
            NSCursor.closedHand.push()
            return true

        case .leftMouseDragged:
            guard let state = webcamDragState,
                  let panel = panels[state.displayID],
                  let location = topLeftLocation(for: event, in: panel)
            else { return false }

            model.updateWebcamPlacement(to: location, in: state.captureFrame)
            return true

        case .leftMouseUp:
            guard let state = webcamDragState else { return false }
            if let panel = panels[state.displayID],
               let location = topLeftLocation(for: event, in: panel) {
                model.updateWebcamPlacement(to: location, in: state.captureFrame)
            }
            webcamDragState = nil
            NSCursor.pop()
            return true

        default:
            return false
        }
    }

    private func webcamDragContext(
        for event: NSEvent
    ) -> (display: CaptureDisplay, captureFrame: CGRect, bubbleFrame: CGRect, location: CGPoint)? {
        guard let (displayID, panel) = panels.first(where: { $0.value.windowNumber == event.windowNumber }),
              displayID == model.activeDisplayID,
              let display = model.displays.first(where: { $0.id == displayID }),
              let location = topLeftLocation(for: event, in: panel)
        else { return nil }

        let captureFrame: CGRect?
        switch model.selectionMode {
        case .region:
            captureFrame = model.hasSelection ? model.selection : nil
        case .window:
            captureFrame = model.selectedWindow == nil ? nil : model.windowHighlightFrame(on: display)
        }

        guard let captureFrame else { return nil }
        return (
            display,
            captureFrame,
            model.webcamBubbleFrame(in: captureFrame),
            location
        )
    }

    private func topLeftLocation(for event: NSEvent, in panel: CropperPanel) -> CGPoint? {
        guard let contentView = panel.contentView else { return nil }
        let local = contentView.convert(event.locationInWindow, from: nil)
        if contentView.isFlipped {
            return local
        }
        return CGPoint(x: local.x, y: contentView.bounds.height - local.y)
    }

    /// Uses `CGWindowList` z-order so fullscreen utility overlays (Magnet, etc.)
    /// can be skipped and child surfaces promote to the capturable outer window.
    private func captureWindowUnderCursor(at location: CGPoint) -> CaptureWindow? {
        let overlayNumbers = Set(panels.values.map(\.windowNumber))
        let hits = WindowGeometry.windowServerHits(
            at: location,
            excludingWindowNumbers: overlayNumbers
        )
        return WindowGeometry.captureWindow(
            at: location,
            hitsFrontToBack: hits,
            in: model.availableWindows
        )
    }

    private func removeEventMonitors() {
        if webcamDragState != nil {
            webcamDragState = nil
            NSCursor.pop()
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }
}

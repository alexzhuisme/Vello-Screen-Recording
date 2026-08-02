import AppKit
import Observation
import VelloCapture
import VelloCore
import VelloUI

enum SelectionMode: String, Sendable, Equatable {
    case region
    case window
}

/// Shared state for the crop overlays. One instance drives every display's panel,
/// so only one display can hold the selection at a time.
@MainActor
@Observable
final class CropperModel {
    var displays: [CaptureDisplay] = []
    var activeDisplayID: CGDirectDisplayID?

    /// Capture region in the active display's local points, top-left origin.
    var selection: CGRect = .zero

    var selectionMode: SelectionMode = .region
    var availableWindows: [CaptureWindow] = []
    var hoveredWindowID: CGWindowID?
    /// Live WindowServer bounds for the hovered / selected window (global, bottom-left).
    var highlightFrame: CGRect?
    var selectedWindow: CaptureWindow?

    var isRecording = false
    var isPaused = false

    var audioInputDevices: [AudioInputDevice] = []
    var microphoneAvailable = false

    @ObservationIgnored let settings: Settings

    @ObservationIgnored var onStartRecording: ((CaptureTarget) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
    @ObservationIgnored var onOpenPreferences: (() -> Void)?

    init(settings: Settings) {
        self.settings = settings
    }

    var activeDisplay: CaptureDisplay? {
        displays.first { $0.id == activeDisplayID }
    }

    var hasSelection: Bool {
        switch selectionMode {
        case .region:
            selection.width >= VelloMetrics.minimumCropSize.width
                && selection.height >= VelloMetrics.minimumCropSize.height
        case .window:
            selectedWindow != nil
        }
    }

    /// Pixel dimensions the recording will have, accounting for display scale.
    var selectionPixelSize: CGSize {
        switch selectionMode {
        case .region:
            let scale = activeDisplay?.scaleFactor ?? 2
            return CGSize(
                width: (selection.width * scale).rounded(),
                height: (selection.height * scale).rounded()
            )
        case .window:
            guard let window = selectedWindow else { return .zero }
            let scale = scaleFactor(for: window.frame)
            return CGSize(
                width: (window.frame.width * scale).rounded(),
                height: (window.frame.height * scale).rounded()
            )
        }
    }

    var highlightedWindow: CaptureWindow? {
        if let selectedWindow { return selectedWindow }
        guard let hoveredWindowID else { return nil }
        return availableWindows.first { $0.id == hoveredWindowID }
    }

    /// Display-local top-left frame for the currently highlighted / selected window on `display`.
    /// Uses WindowServer bounds as-is — guessing a shadow inset was clipping real chrome.
    func windowHighlightFrame(on display: CaptureDisplay) -> CGRect? {
        let global: CGRect?
        if let highlightFrame {
            global = highlightFrame
        } else if let window = highlightedWindow {
            global = window.frame
        } else {
            global = nil
        }
        guard let global, global.intersects(display.frame) else { return nil }
        return WindowGeometry.displayLocalFrame(global, on: display)
    }

    /// Label for the window under the cursor or the confirmed selection.
    var highlightedWindowSummary: String? {
        guard let window = highlightedWindow else { return nil }
        if window.title.isEmpty || window.title == window.applicationName {
            return window.applicationName
        }
        return "\(window.applicationName) — \(window.title)"
    }

    var windowSummary: String {
        highlightedWindowSummary ?? "Select a window"
    }

    func prepare(displays: [CaptureDisplay], preferredDisplayID: CGDirectDisplayID?) {
        self.displays = displays
        selectionMode = .region
        hoveredWindowID = nil
        highlightFrame = nil
        selectedWindow = nil

        let target = preferredDisplayID ?? activeDisplayID ?? displays.first?.id
        activeDisplayID = displays.contains { $0.id == target } ? target : displays.first?.id

        guard let display = activeDisplay else { return }
        let bounds = CGRect(origin: .zero, size: display.frame.size)

        // Restore the previous region when it still fits, otherwise start centred.
        if let remembered = settings.lastSelection, bounds.contains(remembered), remembered.width > 0 {
            selection = remembered
        } else {
            selection = SelectionGeometry.defaultSelection(in: bounds)
        }

        // Warm the window list so Space → window mode can highlight immediately.
        Task { await refreshWindows() }
    }

    func bounds(for display: CaptureDisplay) -> CGRect {
        CGRect(origin: .zero, size: display.frame.size)
    }

    func beginSelection(on displayID: CGDirectDisplayID) {
        guard selectionMode == .region else { return }
        guard activeDisplayID != displayID else { return }
        activeDisplayID = displayID
        selection = .zero
    }

    func commitSelection() {
        guard selectionMode == .region, hasSelection else { return }
        settings.lastSelection = selection
    }

    func setSelectionSize(_ size: CGSize) {
        guard selectionMode == .region, let display = activeDisplay else { return }
        let bounds = self.bounds(for: display)
        let width = min(size.width, bounds.width)
        let height = min(size.height, bounds.height)
        let centred = CGRect(
            x: ((bounds.width - width) / 2).rounded(),
            y: ((bounds.height - height) / 2).rounded(),
            width: width,
            height: height
        )
        selection = centred
        commitSelection()
    }

    func selectFullDisplay() {
        guard selectionMode == .region, let display = activeDisplay else { return }
        selection = bounds(for: display)
        commitSelection()
    }

    func toggleSelectionMode() {
        switch selectionMode {
        case .region:
            enterWindowMode()
        case .window:
            enterRegionMode()
        }
    }

    func enterWindowMode() {
        selectionMode = .window
        hoveredWindowID = nil
        highlightFrame = nil
        selectedWindow = nil
        Task { await refreshWindows() }
    }

    func enterRegionMode() {
        selectionMode = .region
        hoveredWindowID = nil
        highlightFrame = nil
        selectedWindow = nil

        guard let display = activeDisplay else { return }
        let bounds = self.bounds(for: display)
        if let remembered = settings.lastSelection, bounds.contains(remembered), remembered.width > 0 {
            selection = remembered
        } else if !hasSelection {
            selection = SelectionGeometry.defaultSelection(in: bounds)
        }
    }

    func refreshWindows() async {
        guard let windows = try? await CaptureDevices.windows() else { return }
        availableWindows = windows

        if let selected = selectedWindow,
           let updated = windows.first(where: { $0.id == selected.id }) {
            selectedWindow = updated
            highlightFrame = updated.frame
        } else if selectedWindow != nil {
            selectedWindow = nil
            highlightFrame = nil
        }

        if let hovered = hoveredWindowID {
            if let updated = windows.first(where: { $0.id == hovered }) {
                highlightFrame = updated.frame
            } else {
                hoveredWindowID = nil
                highlightFrame = nil
            }
        }
    }

    func updateHover(window: CaptureWindow?, on display: CaptureDisplay) {
        guard selectionMode == .window, selectedWindow == nil else { return }
        hoveredWindowID = window?.id
        highlightFrame = window?.frame
        activeDisplayID = display.id
    }

    func selectHoveredWindow(on display: CaptureDisplay) {
        guard selectionMode == .window else { return }
        guard let window = highlightedWindow else { return }
        let frame = highlightFrame ?? window.frame
        selectedWindow = window.withFrame(frame)
        highlightFrame = frame
        hoveredWindowID = nil
        activeDisplayID = display.id
    }

    func clearWindowSelection() {
        selectedWindow = nil
        hoveredWindowID = nil
        highlightFrame = nil
    }

    func startRecording() {
        guard hasSelection else { return }

        switch selectionMode {
        case .region:
            guard let displayID = activeDisplayID else { return }
            commitSelection()
            onStartRecording?(
                .display(displayID: displayID, cropRect: SelectionGeometry.evenSized(selection))
            )
        case .window:
            guard let window = selectedWindow else { return }
            onStartRecording?(.window(windowID: window.id))
        }
    }

    // MARK: - Microphone

    var microphoneSummary: String {
        guard settings.recordAudio else { return "Off" }
        let stored = settings.audioInputDeviceID
        if stored == systemDefaultAudioDeviceID {
            return CaptureDevices.defaultAudioInputDevice()?.name ?? "System Default"
        }
        return audioInputDevices.first { $0.id == stored }?.name ?? "System Default"
    }

    func refreshAudioDevices() {
        audioInputDevices = CaptureDevices.audioInputDevices()
        microphoneAvailable = Permissions.microphoneStatus != .denied && !audioInputDevices.isEmpty
    }

    private func scaleFactor(for globalFrame: CGRect) -> CGFloat {
        let center = CGPoint(x: globalFrame.midX, y: globalFrame.midY)
        return displays.first { $0.frame.contains(center) }?.scaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
    }
}

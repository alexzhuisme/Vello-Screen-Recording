import AppKit
import Observation
import VelloCapture
import VelloCore
import VelloUI

/// Shared state for the crop overlays. One instance drives every display's panel,
/// so only one display can hold the selection at a time.
@MainActor
@Observable
final class CropperModel {
    var displays: [CaptureDisplay] = []
    var activeDisplayID: CGDirectDisplayID?

    /// Capture region in the active display's local points, top-left origin.
    var selection: CGRect = .zero

    var isRecording = false
    var isPaused = false

    var audioInputDevices: [AudioInputDevice] = []
    var microphoneAvailable = false

    @ObservationIgnored let settings: Settings

    @ObservationIgnored var onStartRecording: ((CGDirectDisplayID, CGRect) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
    @ObservationIgnored var onOpenPreferences: (() -> Void)?

    init(settings: Settings) {
        self.settings = settings
    }

    var activeDisplay: CaptureDisplay? {
        displays.first { $0.id == activeDisplayID }
    }

    var hasSelection: Bool {
        selection.width >= VelloMetrics.minimumCropSize.width
            && selection.height >= VelloMetrics.minimumCropSize.height
    }

    /// Pixel dimensions the recording will have, accounting for display scale.
    var selectionPixelSize: CGSize {
        let scale = activeDisplay?.scaleFactor ?? 2
        return CGSize(
            width: (selection.width * scale).rounded(),
            height: (selection.height * scale).rounded()
        )
    }

    func prepare(displays: [CaptureDisplay], preferredDisplayID: CGDirectDisplayID?) {
        self.displays = displays

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
    }

    func bounds(for display: CaptureDisplay) -> CGRect {
        CGRect(origin: .zero, size: display.frame.size)
    }

    func beginSelection(on displayID: CGDirectDisplayID) {
        guard activeDisplayID != displayID else { return }
        activeDisplayID = displayID
        selection = .zero
    }

    func commitSelection() {
        guard hasSelection else { return }
        settings.lastSelection = selection
    }

    func setSelectionSize(_ size: CGSize) {
        guard let display = activeDisplay else { return }
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
        guard let display = activeDisplay else { return }
        selection = bounds(for: display)
        commitSelection()
    }

    func startRecording() {
        guard hasSelection, let displayID = activeDisplayID else { return }
        commitSelection()
        onStartRecording?(displayID, SelectionGeometry.evenSized(selection))
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
}

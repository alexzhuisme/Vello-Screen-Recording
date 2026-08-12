import AppKit
import VelloCapture
import VelloCore
import VelloUI

/// Owns the app's long-lived objects and wires the record → edit → export flow together.
@MainActor
final class AppCoordinator {
    private let settings = Settings.shared
    private let recorder = ScreenRecorder()
    private let clickHighlighter = ClickHighlighter()
    private let cropperModel: CropperModel
    private let cropperController: CropperWindowController
    private let statusItemController: StatusItemController
    private let hotKeyManager = HotKeyManager()

    private var editors: [EditorWindowController] = []
    private var preferencesController: PreferencesWindowController?

    init() {
        cropperModel = CropperModel(settings: settings)
        cropperController = CropperWindowController(model: cropperModel)
        statusItemController = StatusItemController(settings: settings)
    }

    var isRecording: Bool { recorder.state.isActive }

    func start() {
        TemporaryFiles.purge()
        wireStatusItem()
        wireCropper()
        wireRecorder()
        refreshHotKey()
    }

    // MARK: - Wiring

    private func wireStatusItem() {
        statusItemController.elapsedProvider = { [weak self] in self?.recorder.elapsed ?? 0 }
        statusItemController.onNewRecording = { [weak self] in self?.showCropper() }
        statusItemController.onStop = { [weak self] in self?.stopRecording() }
        statusItemController.onTogglePause = { [weak self] in self?.togglePause() }
        statusItemController.onPreferences = { [weak self] in self?.showPreferences() }
        statusItemController.onAbout = { [weak self] in self?.showAbout() }
        statusItemController.onQuit = { NSApp.terminate(nil) }
    }

    private func wireCropper() {
        cropperModel.onStartRecording = { [weak self] target in
            self?.startRecording(target)
        }
        cropperModel.onCancel = { [weak self] in self?.hideCropper() }
        cropperModel.onOpenPreferences = { [weak self] in
            self?.hideCropper()
            self?.showPreferences()
        }
    }

    private func wireRecorder() {
        recorder.onUnexpectedStop = { [weak self] error in
            guard let self else { return }
            clickHighlighter.stop()
            cropperController.setRecording(false)
            cropperController.close()
            statusItemController.apply(state: .idle)
            present(error)
        }
    }

    func refreshHotKey() {
        hotKeyManager.unregister()
        guard settings.enableShortcuts, let combo = settings.toggleCropperShortcut else { return }
        hotKeyManager.register(combo) { [weak self] in self?.handleShortcut() }
    }

    /// The same shortcut opens the cropper and, once recording, stops it.
    private func handleShortcut() {
        if recorder.state.isActive {
            stopRecording()
        } else if cropperController.isVisible {
            hideCropper()
        } else {
            showCropper()
        }
    }

    // MARK: - Cropper

    func showCropper() {
        guard !recorder.state.isActive else { return }

        Task {
            guard await ensureScreenRecordingPermission() else { return }
            do {
                let displays = try await CaptureDevices.displays()
                guard !displays.isEmpty else {
                    present(RecordingError.displayUnavailable)
                    return
                }
                let preferred = NSScreen.main?.displayID
                cropperController.show(displays: displays, preferredDisplayID: preferred)
            } catch {
                present(error)
            }
        }
    }

    func hideCropper() {
        guard !recorder.state.isActive else { return }
        cropperController.close()
    }

    // MARK: - Recording

    private func startRecording(_ target: CaptureTarget) {
        Task {
            let audioDeviceID = await resolveMicrophone()
            let audioMode = resolvedAudioMode(microphoneDeviceID: audioDeviceID)

            // Click highlights only work on display streams (window capture
            // records a single SCWindow, so Vello overlays never appear).
            let includedWindowIDs: [CGWindowID]
            let isWindowTarget: Bool
            if case .window = target {
                isWindowTarget = true
                includedWindowIDs = []
            } else if settings.highlightClicks {
                isWindowTarget = false
                clickHighlighter.start()
                // Give WindowServer a beat to publish the new windows to SCK.
                try? await Task.sleep(for: .milliseconds(50))
                includedWindowIDs = clickHighlighter.windowIDs
            } else {
                isWindowTarget = false
                includedWindowIDs = []
            }

            let configuration = RecordingConfiguration(
                target: target,
                frameRate: settings.recordingFrameRate,
                showsCursor: settings.showsCursor || (!isWindowTarget && settings.highlightClicks),
                audioMode: audioMode,
                audioDeviceID: audioDeviceID
            )

            do {
                try await recorder.start(configuration, includedWindowIDs: includedWindowIDs)
                cropperController.setRecording(true, hidesOverlay: isWindowTarget)
                statusItemController.apply(state: .recording)
            } catch {
                clickHighlighter.stop()
                cropperController.setRecording(false)
                cropperController.close()
                statusItemController.apply(state: .idle)
                present(error)
            }
        }
    }

    func stopRecording() {
        guard recorder.state.isActive else { return }

        Task {
            defer {
                clickHighlighter.stop()
                cropperController.setRecording(false)
                cropperController.close()
                statusItemController.apply(state: .idle)
            }

            do {
                let recording = try await recorder.stop()
                presentEditor(for: recording)
            } catch {
                present(error)
            }
        }
    }

    func togglePause() {
        switch recorder.state {
        case .recording:
            recorder.pause()
            clickHighlighter.setPaused(true)
            cropperModel.isPaused = true
            statusItemController.apply(state: .paused)
        case .paused:
            recorder.resume()
            clickHighlighter.setPaused(false)
            cropperModel.isPaused = false
            statusItemController.apply(state: .recording)
        default:
            break
        }
    }

    /// Stops a recording during quit without opening an editor for it.
    func stopRecordingForTermination() async {
        guard recorder.state.isActive else { return }
        clickHighlighter.stop()
        await recorder.cancel()
        cropperController.setRecording(false)
        cropperController.close()
    }

    // MARK: - Editor

    private func presentEditor(for recording: Recording) {
        let model = EditorModel(recording: recording, settings: settings)
        let controller = EditorWindowController(model: model)
        controller.onClose = { [weak self] closed in
            self?.editors.removeAll { $0 === closed }
            self?.updateActivationPolicy()
        }
        editors.append(controller)
        updateActivationPolicy()
        controller.show()
    }

    // MARK: - Preferences

    func showPreferences() {
        let controller = preferencesController ?? PreferencesWindowController(settings: settings)
        controller.onClose = { [weak self] in
            self?.preferencesController = nil
            self?.refreshHotKey()
            self?.updateActivationPolicy()
        }
        preferencesController = controller
        updateActivationPolicy()
        controller.show()
    }

    private func showAbout() {
        hideCropper()
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    /// Vello is a menu bar app, so it only claims a dock icon while a window is open.
    private func updateActivationPolicy() {
        let wantsDock = !editors.isEmpty || preferencesController != nil
        NSApp.setActivationPolicy(wantsDock ? .regular : .accessory)
    }

    // MARK: - Permissions

    private func ensureScreenRecordingPermission() async -> Bool {
        // Prefer ScreenCaptureKit over CGPreflight — Debug builds often leave
        // CGPreflight false even when the System Settings toggle is On.
        if await Permissions.verifyScreenRecordingAccess() { return true }

        // Surfaces the system prompt the first time; later calls only report.
        _ = Permissions.requestScreenRecordingAccess()
        if await Permissions.verifyScreenRecordingAccess() { return true }

        let alert = NSAlert()
        alert.messageText = "Vello needs permission to record your screen"
        // macOS binds Screen Recording permission to this process's code signature.
        // Enabling the toggle is not enough while the current process is still running —
        // TCC only takes effect after a full quit and relaunch.
        alert.informativeText = """
        Open System Settings › Privacy & Security › Screen & System Audio Recording \
        and turn on Vello.

        Vello will quit so macOS can apply the change. When you are done, open Vello again.
        """
        alert.addButton(withTitle: "Open Settings & Quit")
        alert.alertStyle = .warning

        NSApp.activate()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Permissions.openScreenRecordingSettings()
            NSApp.terminate(nil)
        }
        return false
    }

    /// Returns the device to record, prompting for access the first time and
    /// silently continuing without audio if the user declines.
    private func resolveMicrophone() async -> String? {
        guard settings.audioCaptureMode.includesMicrophone else { return nil }

        if Permissions.microphoneStatus == .notDetermined {
            _ = await Permissions.requestMicrophoneAccess()
        }
        guard Permissions.microphoneStatus == .granted else {
            Log.app.notice("Microphone access unavailable; recording without audio")
            return nil
        }
        return CaptureDevices.resolveAudioDeviceID(settings.audioInputDeviceID)
    }

    /// If microphone access is unavailable, keep system audio when the user
    /// selected Both and otherwise continue silently, matching the previous UX.
    private func resolvedAudioMode(microphoneDeviceID: String?) -> AudioCaptureMode {
        guard settings.audioCaptureMode.includesMicrophone, microphoneDeviceID == nil else {
            return settings.audioCaptureMode
        }
        return settings.audioCaptureMode.includesSystemAudio ? .systemAudio : .off
    }

    // MARK: - Errors

    private func present(_ error: Error) {
        Log.app.error("\(error.localizedDescription, privacy: .public)")

        let alert = NSAlert()
        alert.messageText = (error as? LocalizedError)?.errorDescription ?? "Something went wrong"
        alert.informativeText = (error as? LocalizedError)?.recoverySuggestion
            ?? error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        NSApp.activate()
        alert.runModal()
    }
}

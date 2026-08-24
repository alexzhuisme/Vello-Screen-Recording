import Foundation
import Observation

/// Sentinel meaning "follow the system default input device" rather than a pinned one.
public let systemDefaultAudioDeviceID = "SYSTEM_DEFAULT"

@MainActor
@Observable
public final class Settings {
    public static let shared = Settings()

    @ObservationIgnored private let defaults: UserDefaults

    public var showsCursor: Bool {
        didSet {
            defaults.set(showsCursor, forKey: Key.showsCursor)
            // Highlighting clicks with an invisible cursor is useless.
            if !showsCursor, highlightClicks {
                highlightClicks = false
            }
        }
    }

    /// Draws an expanding ring under each mouse click in the recording.
    /// Enabling this also forces the cursor to stay visible, matching Kap's behaviour.
    public var highlightClicks: Bool {
        didSet {
            defaults.set(highlightClicks, forKey: Key.highlightClicks)
            if highlightClicks, !showsCursor {
                showsCursor = true
            }
        }
    }

    public var audioCaptureMode: AudioCaptureMode {
        didSet { defaults.set(audioCaptureMode.rawValue, forKey: Key.audioCaptureMode) }
    }

    public var audioInputDeviceID: String? {
        didSet { defaults.set(audioInputDeviceID, forKey: Key.audioInputDeviceID) }
    }

    /// Capture frame rate. Only 30 and 60 are offered in the UI.
    public var recordingFrameRate: Int {
        didSet { defaults.set(recordingFrameRate, forKey: Key.recordingFrameRate) }
    }

    public var recordingCountdown: RecordingCountdown {
        didSet { defaults.set(recordingCountdown.rawValue, forKey: Key.recordingCountdown) }
    }

    public var webcamEnabled: Bool {
        didSet { defaults.set(webcamEnabled, forKey: Key.webcamEnabled) }
    }

    public var webcamDeviceID: String? {
        didSet { defaults.set(webcamDeviceID, forKey: Key.webcamDeviceID) }
    }

    public var webcamPosition: WebcamPosition {
        didSet { defaults.set(webcamPosition.rawValue, forKey: Key.webcamPosition) }
    }

    public var webcamCustomPosition: WebcamCustomPosition {
        didSet {
            defaults.set(
                try? JSONEncoder().encode(webcamCustomPosition),
                forKey: Key.webcamCustomPosition
            )
        }
    }

    public var webcamSize: WebcamSize {
        didSet { defaults.set(webcamSize.rawValue, forKey: Key.webcamSize) }
    }

    /// Whether Vello has already presented its first-launch permission setup.
    /// The individual system permissions remain the source of truth; this flag
    /// only prevents the explanatory setup alert from appearing every launch.
    public var didShowInitialPermissionSetup: Bool {
        didSet {
            defaults.set(didShowInitialPermissionSetup, forKey: Key.didShowInitialPermissionSetup)
        }
    }

    public var loopAnimatedExports: Bool {
        didSet { defaults.set(loopAnimatedExports, forKey: Key.loopAnimatedExports) }
    }

    public var defaultExportFormat: ExportFormat {
        didSet { defaults.set(defaultExportFormat.rawValue, forKey: Key.defaultExportFormat) }
    }

    public var exportPresets: [ExportPreset] {
        didSet {
            defaults.set(try? JSONEncoder().encode(exportPresets), forKey: Key.exportPresets)
        }
    }

    public var enableShortcuts: Bool {
        didSet { defaults.set(enableShortcuts, forKey: Key.enableShortcuts) }
    }

    public var toggleCropperShortcut: HotKeyCombo? {
        didSet {
            let data = toggleCropperShortcut.flatMap { try? JSONEncoder().encode($0) }
            defaults.set(data, forKey: Key.toggleCropperShortcut)
        }
    }

    /// Whether exports should show a save panel instead of using Downloads or
    /// a remembered custom folder.
    public var asksForSaveLocation: Bool {
        didSet { defaults.set(asksForSaveLocation, forKey: Key.asksForSaveLocation) }
    }

    /// Bookmark for a custom folder. `nil` uses Downloads unless
    /// `asksForSaveLocation` is enabled.
    public var saveDirectoryBookmark: Data? {
        didSet { defaults.set(saveDirectoryBookmark, forKey: Key.saveDirectoryBookmark) }
    }

    /// Cached display path for the save directory, so preferences can render a
    /// label without paying the cost of resolving the bookmark.
    public var saveDirectoryPath: String? {
        didSet { defaults.set(saveDirectoryPath, forKey: Key.saveDirectoryPath) }
    }

    /// Most recent capture region, in display-local points with a top-left origin,
    /// so reopening the cropper restores what the user last framed.
    public var lastSelection: CGRect? {
        didSet {
            let encoded = lastSelection.map {
                [$0.origin.x, $0.origin.y, $0.size.width, $0.size.height]
            }
            defaults.set(encoded, forKey: Key.lastSelection)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        showsCursor = defaults.object(forKey: Key.showsCursor) as? Bool ?? true
        highlightClicks = defaults.bool(forKey: Key.highlightClicks)
        if let storedMode = defaults.string(forKey: Key.audioCaptureMode)
            .flatMap(AudioCaptureMode.init(rawValue:)) {
            audioCaptureMode = storedMode
        } else {
            // Migrate the original microphone-only preference.
            audioCaptureMode = defaults.bool(forKey: Key.recordAudio) ? .microphone : .off
        }
        audioInputDeviceID = defaults.string(forKey: Key.audioInputDeviceID) ?? systemDefaultAudioDeviceID
        recordingFrameRate = defaults.object(forKey: Key.recordingFrameRate) as? Int ?? 60
        recordingCountdown = (defaults.object(forKey: Key.recordingCountdown) as? Int)
            .flatMap(RecordingCountdown.init(rawValue:)) ?? .threeSeconds
        webcamEnabled = defaults.bool(forKey: Key.webcamEnabled)
        webcamDeviceID = defaults.string(forKey: Key.webcamDeviceID)
        webcamPosition = defaults.string(forKey: Key.webcamPosition)
            .flatMap(WebcamPosition.init(rawValue:)) ?? .bottomRight
        webcamCustomPosition = defaults.data(forKey: Key.webcamCustomPosition)
            .flatMap { try? JSONDecoder().decode(WebcamCustomPosition.self, from: $0) }
            ?? .center
        webcamSize = defaults.string(forKey: Key.webcamSize)
            .flatMap(WebcamSize.init(rawValue:)) ?? .medium
        didShowInitialPermissionSetup = defaults.bool(forKey: Key.didShowInitialPermissionSetup)
        loopAnimatedExports = defaults.object(forKey: Key.loopAnimatedExports) as? Bool ?? true
        defaultExportFormat = defaults.string(forKey: Key.defaultExportFormat)
            .flatMap(ExportFormat.init(rawValue:)) ?? .mp4
        exportPresets = defaults.data(forKey: Key.exportPresets)
            .flatMap { try? JSONDecoder().decode([ExportPreset].self, from: $0) } ?? []
        enableShortcuts = defaults.object(forKey: Key.enableShortcuts) as? Bool ?? true
        toggleCropperShortcut = (defaults.data(forKey: Key.toggleCropperShortcut))
            .flatMap { try? JSONDecoder().decode(HotKeyCombo.self, from: $0) }
            ?? .defaultToggleCropper
        asksForSaveLocation = defaults.bool(forKey: Key.asksForSaveLocation)
        saveDirectoryBookmark = defaults.data(forKey: Key.saveDirectoryBookmark)
        saveDirectoryPath = defaults.string(forKey: Key.saveDirectoryPath)

        if let stored = defaults.array(forKey: Key.lastSelection) as? [Double], stored.count == 4 {
            lastSelection = CGRect(x: stored[0], y: stored[1], width: stored[2], height: stored[3])
        } else {
            lastSelection = nil
        }

        // didSet does not run during init, so re-assert the Kap coupling here.
        if highlightClicks {
            showsCursor = true
        }
    }

    /// Microphone to record with, or `nil` when audio is disabled.
    public var effectiveAudioDeviceID: String? {
        guard audioCaptureMode.includesMicrophone else { return nil }
        return audioInputDeviceID
    }

    // MARK: - Save destination

    /// Resolves the remembered save folder, refreshing the bookmark if the OS
    /// reports it stale. With no custom folder, Downloads is the default.
    /// Returns `nil` only when the user has selected "Ask Every Time".
    public func resolveSaveDirectory() -> URL? {
        if let saveDirectoryBookmark {
            do {
                let (url, isStale) = try SecurityScopedBookmark.resolve(saveDirectoryBookmark)
                if isStale {
                    try? rememberSaveDirectory(url)
                }
                return url
            } catch {
                Log.settings.error("Discarding unresolvable save directory bookmark: \(error.localizedDescription)")
                self.saveDirectoryBookmark = nil
                saveDirectoryPath = nil
            }
        }

        guard !asksForSaveLocation else { return nil }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    public func rememberSaveDirectory(_ url: URL) throws {
        saveDirectoryBookmark = try SecurityScopedBookmark.create(for: url)
        saveDirectoryPath = url.path(percentEncoded: false)
        asksForSaveLocation = false
    }

    public func useDownloadsDirectory() {
        saveDirectoryBookmark = nil
        saveDirectoryPath = nil
        asksForSaveLocation = false
    }

    public func askForSaveLocationEveryTime() {
        saveDirectoryBookmark = nil
        saveDirectoryPath = nil
        asksForSaveLocation = true
    }

    public var saveDirectoryDisplayName: String {
        guard let saveDirectoryPath else {
            return asksForSaveLocation ? "Ask every time" : "Downloads"
        }
        return URL(fileURLWithPath: saveDirectoryPath).lastPathComponent
    }

    private enum Key {
        static let showsCursor = "showsCursor"
        static let highlightClicks = "highlightClicks"
        static let audioCaptureMode = "audioCaptureMode"
        /// Retained only to migrate preferences written by builds before audio modes.
        static let recordAudio = "recordAudio"
        static let audioInputDeviceID = "audioInputDeviceID"
        static let recordingFrameRate = "recordingFrameRate"
        static let recordingCountdown = "recordingCountdown"
        static let webcamEnabled = "webcamEnabled"
        static let webcamDeviceID = "webcamDeviceID"
        static let webcamPosition = "webcamPosition"
        static let webcamCustomPosition = "webcamCustomPosition"
        static let webcamSize = "webcamSize"
        static let didShowInitialPermissionSetup = "didShowInitialPermissionSetup"
        static let loopAnimatedExports = "loopAnimatedExports"
        static let defaultExportFormat = "defaultExportFormat"
        static let exportPresets = "exportPresets"
        static let enableShortcuts = "enableShortcuts"
        static let toggleCropperShortcut = "toggleCropperShortcut"
        static let asksForSaveLocation = "asksForSaveLocation"
        static let saveDirectoryBookmark = "saveDirectoryBookmark"
        static let saveDirectoryPath = "saveDirectoryPath"
        static let lastSelection = "lastSelection"
    }
}

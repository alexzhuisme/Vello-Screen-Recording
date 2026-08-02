import Foundation
import Observation

/// Sentinel meaning "follow the system default input device" rather than a pinned one.
public let systemDefaultAudioDeviceID = "SYSTEM_DEFAULT"

@MainActor
@Observable
public final class Settings {
    public static let shared = Settings()

    @ObservationIgnored private let defaults: UserDefaults

    public var showsCursor: Bool { didSet { defaults.set(showsCursor, forKey: Key.showsCursor) } }
    public var recordAudio: Bool { didSet { defaults.set(recordAudio, forKey: Key.recordAudio) } }

    public var audioInputDeviceID: String? {
        didSet { defaults.set(audioInputDeviceID, forKey: Key.audioInputDeviceID) }
    }

    /// Capture frame rate. Only 30 and 60 are offered in the UI.
    public var recordingFrameRate: Int {
        didSet { defaults.set(recordingFrameRate, forKey: Key.recordingFrameRate) }
    }

    public var loopAnimatedExports: Bool {
        didSet { defaults.set(loopAnimatedExports, forKey: Key.loopAnimatedExports) }
    }

    public var defaultExportFormat: ExportFormat {
        didSet { defaults.set(defaultExportFormat.rawValue, forKey: Key.defaultExportFormat) }
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

    /// Bookmark for the folder exports are written to. `nil` means "ask each time".
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
        recordAudio = defaults.bool(forKey: Key.recordAudio)
        audioInputDeviceID = defaults.string(forKey: Key.audioInputDeviceID) ?? systemDefaultAudioDeviceID
        recordingFrameRate = defaults.object(forKey: Key.recordingFrameRate) as? Int ?? 30
        loopAnimatedExports = defaults.object(forKey: Key.loopAnimatedExports) as? Bool ?? true
        defaultExportFormat = defaults.string(forKey: Key.defaultExportFormat)
            .flatMap(ExportFormat.init(rawValue:)) ?? .mp4
        enableShortcuts = defaults.object(forKey: Key.enableShortcuts) as? Bool ?? true
        toggleCropperShortcut = (defaults.data(forKey: Key.toggleCropperShortcut))
            .flatMap { try? JSONDecoder().decode(HotKeyCombo.self, from: $0) }
            ?? .defaultToggleCropper
        saveDirectoryBookmark = defaults.data(forKey: Key.saveDirectoryBookmark)
        saveDirectoryPath = defaults.string(forKey: Key.saveDirectoryPath)

        if let stored = defaults.array(forKey: Key.lastSelection) as? [Double], stored.count == 4 {
            lastSelection = CGRect(x: stored[0], y: stored[1], width: stored[2], height: stored[3])
        } else {
            lastSelection = nil
        }
    }

    /// Microphone to record with, or `nil` when audio is disabled.
    public var effectiveAudioDeviceID: String? {
        guard recordAudio else { return nil }
        return audioInputDeviceID
    }

    // MARK: - Save destination

    /// Resolves the remembered save folder, refreshing the bookmark if the OS
    /// reports it stale. Returns `nil` when no folder has been chosen yet.
    public func resolveSaveDirectory() -> URL? {
        guard let saveDirectoryBookmark else { return nil }
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
            return nil
        }
    }

    public func rememberSaveDirectory(_ url: URL) throws {
        saveDirectoryBookmark = try SecurityScopedBookmark.create(for: url)
        saveDirectoryPath = url.path(percentEncoded: false)
    }

    public var saveDirectoryDisplayName: String {
        guard let saveDirectoryPath else { return "Ask every time" }
        return URL(fileURLWithPath: saveDirectoryPath).lastPathComponent
    }

    private enum Key {
        static let showsCursor = "showsCursor"
        static let recordAudio = "recordAudio"
        static let audioInputDeviceID = "audioInputDeviceID"
        static let recordingFrameRate = "recordingFrameRate"
        static let loopAnimatedExports = "loopAnimatedExports"
        static let defaultExportFormat = "defaultExportFormat"
        static let enableShortcuts = "enableShortcuts"
        static let toggleCropperShortcut = "toggleCropperShortcut"
        static let saveDirectoryBookmark = "saveDirectoryBookmark"
        static let saveDirectoryPath = "saveDirectoryPath"
        static let lastSelection = "lastSelection"
    }
}

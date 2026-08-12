import CoreGraphics
import Foundation

/// What to capture: a region of a display, or a single application window.
public enum CaptureTarget: Sendable, Equatable {
    /// Cropping is applied within this display. `cropRect` is display-local
    /// points with a top-left origin; `nil` captures the entire display.
    case display(displayID: CGDirectDisplayID, cropRect: CGRect?)

    /// True window capture via ScreenCaptureKit — follows the window as it moves.
    case window(windowID: CGWindowID)
}

/// Audio sources captured alongside the screen recording.
public enum AudioCaptureMode: String, Sendable, Hashable, CaseIterable, Identifiable {
    case off
    case systemAudio
    case microphone
    case systemAudioAndMicrophone

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: "Off"
        case .systemAudio: "System Audio"
        case .microphone: "Microphone"
        case .systemAudioAndMicrophone: "System Audio + Microphone"
        }
    }

    public var includesSystemAudio: Bool {
        self == .systemAudio || self == .systemAudioAndMicrophone
    }

    public var includesMicrophone: Bool {
        self == .microphone || self == .systemAudioAndMicrophone
    }

    public var recordsAudio: Bool { self != .off }
}

/// Everything needed to start a capture session.
public struct RecordingConfiguration: Sendable, Equatable {
    public var target: CaptureTarget
    public var frameRate: Int
    public var showsCursor: Bool

    public var audioMode: AudioCaptureMode

    /// Unique ID of the microphone to record. Ignored when `audioMode` does not
    /// include microphone capture.
    public var audioDeviceID: String?

    public init(
        target: CaptureTarget,
        frameRate: Int = 30,
        showsCursor: Bool = true,
        audioMode: AudioCaptureMode = .off,
        audioDeviceID: String? = nil
    ) {
        self.target = target
        self.frameRate = frameRate
        self.showsCursor = showsCursor
        self.audioMode = audioMode
        self.audioDeviceID = audioDeviceID
    }

    public var recordsSystemAudio: Bool { audioMode.includesSystemAudio }
    public var recordsMicrophone: Bool { audioMode.includesMicrophone && audioDeviceID != nil }
    public var recordsAudio: Bool { recordsSystemAudio || recordsMicrophone }
}

public enum RecordingState: Sendable, Equatable {
    case idle
    case starting
    case recording
    case paused
    case stopping

    public var isActive: Bool {
        switch self {
        case .recording, .paused: true
        case .idle, .starting, .stopping: false
        }
    }
}

/// Tracks wall-clock recording duration across pause and resume cycles.
public struct RecordingTimeline: Sendable, Equatable {
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    public init() {}

    public var isRunning: Bool { runningSince != nil }

    public mutating func start(at date: Date = .now) {
        accumulated = 0
        runningSince = date
    }

    public mutating func pause(at date: Date = .now) {
        guard let runningSince else { return }
        accumulated += date.timeIntervalSince(runningSince)
        self.runningSince = nil
    }

    public mutating func resume(at date: Date = .now) {
        guard runningSince == nil else { return }
        runningSince = date
    }

    public mutating func reset() {
        accumulated = 0
        runningSince = nil
    }

    public func elapsed(at date: Date = .now) -> TimeInterval {
        guard let runningSince else { return accumulated }
        return accumulated + date.timeIntervalSince(runningSince)
    }
}

/// A finished recording on disk, before any editing or export.
public struct Recording: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public let createdAt: Date
    public let configuration: RecordingConfiguration

    public init(id: UUID = UUID(), url: URL, createdAt: Date = .now, configuration: RecordingConfiguration) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
        self.configuration = configuration
    }

    /// Human-facing default file name, without extension.
    public var defaultFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Vello Recording \(formatter.string(from: createdAt))"
    }
}

public func formatDuration(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}

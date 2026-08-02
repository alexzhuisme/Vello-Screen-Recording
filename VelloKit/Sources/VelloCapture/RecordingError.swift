import Foundation

public enum RecordingError: LocalizedError, Equatable {
    case screenRecordingPermissionDenied
    case displayUnavailable
    case alreadyRecording
    case notRecording
    case emptyRecording
    case writerFailed(String)
    case streamFailed(String)

    public var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            "Vello needs Screen Recording permission to capture your screen."
        case .displayUnavailable:
            "The selected display is no longer available."
        case .alreadyRecording:
            "A recording is already in progress."
        case .notRecording:
            "There is no recording in progress."
        case .emptyRecording:
            "The recording finished without capturing any frames."
        case let .writerFailed(reason):
            "Could not write the recording: \(reason)"
        case let .streamFailed(reason):
            "Screen capture stopped unexpectedly: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            "Open System Settings › Privacy & Security › Screen Recording and enable Vello."
        case .emptyRecording:
            "Try recording again for a little longer."
        default:
            nil
        }
    }
}

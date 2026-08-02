import Foundation

public enum ExportError: LocalizedError, Equatable {
    case sourceHasNoVideoTrack
    case emptyTrimRange
    case exportSessionUnavailable
    case imageDestinationUnavailable
    case noFramesGenerated
    case writeFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .sourceHasNoVideoTrack:
            "The recording does not contain a video track."
        case .emptyTrimRange:
            "The selected range is empty."
        case .exportSessionUnavailable:
            "Could not prepare the video for export."
        case .imageDestinationUnavailable:
            "Could not create the output image file."
        case .noFramesGenerated:
            "No frames could be read from the recording."
        case let .writeFailed(reason):
            "Could not finish writing the file: \(reason)"
        case .cancelled:
            "The export was cancelled."
        }
    }
}

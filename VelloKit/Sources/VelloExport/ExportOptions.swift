import CoreMedia
import Foundation
import VelloCore

/// The edit parameters the editor collects before an export runs.
public struct ExportOptions: Sendable, Equatable {
    public var format: ExportFormat
    /// Trim range within the source recording.
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    /// Output size in pixels. Must be even for video formats.
    public var size: CGSize
    public var frameRate: Int
    public var isMuted: Bool
    public var loops: Bool

    public init(
        format: ExportFormat,
        startTime: TimeInterval,
        endTime: TimeInterval,
        size: CGSize,
        frameRate: Int,
        isMuted: Bool,
        loops: Bool
    ) {
        self.format = format
        self.startTime = startTime
        self.endTime = endTime
        self.size = size
        self.frameRate = frameRate
        self.isMuted = isMuted
        self.loops = loops
    }

    public var duration: TimeInterval { max(0, endTime - startTime) }

    public var timeRange: CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
    }

    /// Animated image formats never carry audio regardless of the mute toggle.
    public var producesAudio: Bool { format.supportsAudio && !isMuted }
}

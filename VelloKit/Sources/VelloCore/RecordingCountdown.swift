import Foundation

/// Delay between confirming a capture target and starting ScreenCaptureKit.
public enum RecordingCountdown: Int, Sendable, Hashable, CaseIterable, Identifiable {
    case off = 0
    case threeSeconds = 3
    case fiveSeconds = 5

    public var id: Int { rawValue }
    public var seconds: Int { rawValue }

    public var displayName: String {
        switch self {
        case .off: "Off"
        case .threeSeconds: "3 seconds"
        case .fiveSeconds: "5 seconds"
        }
    }

    /// Values presented by the overlay before capture begins.
    public var ticks: [Int] {
        guard seconds > 0 else { return [] }
        return Array(stride(from: seconds, through: 1, by: -1))
    }
}

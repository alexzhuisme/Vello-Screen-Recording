import Foundation
import UniformTypeIdentifiers

/// Output formats Vello can produce without any third-party encoder.
public enum ExportFormat: String, CaseIterable, Sendable, Codable, Identifiable {
    case mp4
    case hevc
    case gif
    case apng

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mp4: "MP4"
        case .hevc: "HEVC"
        case .gif: "GIF"
        case .apng: "APNG"
        }
    }

    public var fileExtension: String {
        switch self {
        case .mp4, .hevc: "mp4"
        case .gif: "gif"
        case .apng: "apng"
        }
    }

    public var contentType: UTType {
        switch self {
        case .mp4, .hevc: .mpeg4Movie
        case .gif: .gif
        case .apng: .png
        }
    }

    /// Animated image formats carry no audio track and loop rather than play once.
    public var isAnimatedImage: Bool {
        switch self {
        case .gif, .apng: true
        case .mp4, .hevc: false
        }
    }

    public var supportsAudio: Bool { !isAnimatedImage }
}

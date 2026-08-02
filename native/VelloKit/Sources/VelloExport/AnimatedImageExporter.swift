import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VelloCore

/// Renders a trimmed range of a recording into an animated GIF or APNG using ImageIO,
/// so no third-party encoder is required.
public enum AnimatedImageExporter {
    /// GIF stores frame delays in hundredths of a second, so anything above 50 fps
    /// cannot be represented and only inflates the file.
    private static let maximumGIFFrameRate = 50

    public static func export(
        source: URL,
        to destination: URL,
        options: ExportOptions,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard options.duration > 0 else { throw ExportError.emptyTrimRange }

        let frameRate = options.format == .gif
            ? min(options.frameRate, maximumGIFFrameRate)
            : options.frameRate
        let frameDelay = 1.0 / Double(frameRate)

        let asset = AVURLAsset(url: source)
        let assetDuration = try await asset.load(.duration).seconds
        let start = max(0, options.startTime)
        let end = min(options.endTime, assetDuration)
        guard end > start else { throw ExportError.emptyTrimRange }

        let times = frameTimes(from: start, to: end, delay: frameDelay)
        guard !times.isEmpty else { throw ExportError.noFramesGenerated }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = options.size
        // Half a frame of slack lets the decoder reuse work without visibly drifting.
        let tolerance = CMTime(seconds: frameDelay / 2, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        try? FileManager.default.removeItem(at: destination)

        guard let imageDestination = CGImageDestinationCreateWithURL(
            destination as CFURL,
            options.format.contentType.identifier as CFString,
            times.count,
            nil
        ) else { throw ExportError.imageDestinationUnavailable }

        CGImageDestinationSetProperties(
            imageDestination,
            containerProperties(for: options.format, loops: options.loops) as CFDictionary
        )
        let frameProperties = self.frameProperties(for: options.format, delay: frameDelay) as CFDictionary

        var written = 0
        do {
            for await result in generator.images(for: times) {
                try Task.checkCancellation()
                guard let image = try? result.image else { continue }
                CGImageDestinationAddImage(imageDestination, image, frameProperties)
                written += 1
                onProgress(Double(written) / Double(times.count))
            }
        } catch is CancellationError {
            generator.cancelAllCGImageGeneration()
            try? FileManager.default.removeItem(at: destination)
            throw ExportError.cancelled
        }

        guard written > 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw ExportError.noFramesGenerated
        }

        guard CGImageDestinationFinalize(imageDestination) else {
            try? FileManager.default.removeItem(at: destination)
            throw ExportError.writeFailed("the image file could not be finalized")
        }

        onProgress(1)
    }

    static func frameTimes(from start: Double, to end: Double, delay: Double) -> [CMTime] {
        guard delay > 0, end > start else { return [] }
        let count = max(1, Int(((end - start) / delay).rounded(.down)))
        return (0..<count).map {
            CMTime(seconds: start + Double($0) * delay, preferredTimescale: 600)
        }
    }

    private static func containerProperties(for format: ExportFormat, loops: Bool) -> [CFString: Any] {
        // Zero means loop forever; one plays the animation a single time.
        let loopCount = loops ? 0 : 1
        switch format {
        case .gif:
            return [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]
        case .apng:
            return [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: loopCount]]
        case .mp4, .hevc:
            return [:]
        }
    }

    private static func frameProperties(for format: ExportFormat, delay: Double) -> [CFString: Any] {
        switch format {
        case .gif:
            return [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: delay]]
        case .apng:
            return [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: delay]]
        case .mp4, .hevc:
            return [:]
        }
    }
}

import AVFoundation
import Foundation
import VelloCore

/// Trims, resizes, retimes and optionally mutes a recording into an H.264 or HEVC MP4.
public enum VideoExporter {
    public static func export(
        source: URL,
        to destination: URL,
        options: ExportOptions,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard options.duration > 0 else { throw ExportError.emptyTrimRange }

        let asset = AVURLAsset(url: source)
        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.sourceHasNoVideoTrack
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw ExportError.exportSessionUnavailable }

        let sourceRange = try await clampedRange(options.timeRange, in: asset)
        try videoTrack.insertTimeRange(sourceRange, of: sourceVideoTrack, at: .zero)

        if options.producesAudio,
           let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try audioTrack.insertTimeRange(sourceRange, of: sourceAudioTrack, at: .zero)
        }

        let videoComposition = try await makeVideoComposition(
            for: videoTrack,
            sourceTrack: sourceVideoTrack,
            duration: composition.duration,
            options: options
        )

        let presetName = options.format == .hevc
            ? AVAssetExportPresetHEVCHighestQuality
            : AVAssetExportPresetHighestQuality

        guard let session = AVAssetExportSession(asset: composition, presetName: presetName) else {
            throw ExportError.exportSessionUnavailable
        }
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true

        try await runExport(session: session, to: destination, onProgress: onProgress)
    }

    /// A trim range that extends past the asset produces an empty output, so clamp first.
    private static func clampedRange(_ range: CMTimeRange, in asset: AVAsset) async throws -> CMTimeRange {
        let assetDuration = try await asset.load(.duration)
        let start = CMTimeMaximum(range.start, .zero)
        let end = CMTimeMinimum(range.end, assetDuration)
        guard end > start else { throw ExportError.emptyTrimRange }
        return CMTimeRange(start: start, end: end)
    }

    private static func makeVideoComposition(
        for compositionTrack: AVMutableCompositionTrack,
        sourceTrack: AVAssetTrack,
        duration: CMTime,
        options: ExportOptions
    ) async throws -> AVMutableVideoComposition {
        let naturalSize = try await sourceTrack.load(.naturalSize)
        let preferredTransform = try await sourceTrack.load(.preferredTransform)

        // Rotated sources report their pre-transform size, so measure the displayed size.
        let displayed = naturalSize.applying(preferredTransform)
        let sourceSize = CGSize(width: abs(displayed.width), height: abs(displayed.height))
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw ExportError.sourceHasNoVideoTrack
        }

        let targetSize = CGSize(
            width: evenDimension(options.size.width),
            height: evenDimension(options.size.height)
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(options.frameRate))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        let scale = CGAffineTransform(
            scaleX: targetSize.width / sourceSize.width,
            y: targetSize.height / sourceSize.height
        )
        layerInstruction.setTransform(preferredTransform.concatenating(scale), at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        return videoComposition
    }

    private static func runExport(
        session: AVAssetExportSession,
        to destination: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try? FileManager.default.removeItem(at: destination)

        // AVAssetExportSession is not Sendable, but AVFoundation documents both
        // `states(updateInterval:)` and `cancelExport()` as callable from any thread.
        let sessionBox = UncheckedBox(session)

        let progressTask = Task {
            for await state in sessionBox.value.states(updateInterval: 0.15) {
                if case let .exporting(progress) = state {
                    onProgress(progress.fractionCompleted)
                }
            }
        }
        defer { progressTask.cancel() }

        do {
            try await withTaskCancellationHandler {
                try await session.export(to: destination, as: .mp4)
            } onCancel: {
                sessionBox.value.cancelExport()
            }
        } catch is CancellationError {
            throw ExportError.cancelled
        } catch {
            if Task.isCancelled { throw ExportError.cancelled }
            throw ExportError.writeFailed(error.localizedDescription)
        }

        onProgress(1)
    }

    private struct UncheckedBox<Value>: @unchecked Sendable {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    private static func evenDimension(_ value: CGFloat) -> CGFloat {
        let rounded = Int(value.rounded())
        return CGFloat(max(2, rounded - (rounded % 2)))
    }
}

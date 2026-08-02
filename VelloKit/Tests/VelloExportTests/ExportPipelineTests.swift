import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
import VelloCore
@testable import VelloExport

/// Exercises the real encoders against a synthesized source clip, so the export
/// path is covered without needing screen recording permission.
@MainActor
@Suite("Export pipeline", .serialized)
struct ExportPipelineTests {
    private static let sourceSize = CGSize(width: 320, height: 240)
    private static let sourceFrameRate = 30
    private static let sourceDuration = 2.0

    // MARK: - Tests

    @Test("Exporting to MP4 trims and resizes the source")
    func exportsMP4() async throws {
        let source = try await makeSourceVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let destination = TemporaryFiles.newExportURL(fileExtension: "mp4")
        defer { try? FileManager.default.removeItem(at: destination) }

        let options = ExportOptions(
            format: .mp4,
            startTime: 0.5,
            endTime: 1.5,
            size: CGSize(width: 160, height: 120),
            frameRate: 30,
            isMuted: true,
            loops: false
        )

        let progress = ProgressRecorder()
        try await Exporter.export(source: source, to: destination, options: options) { value in
            progress.record(value)
        }

        #expect(FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)))

        let asset = AVURLAsset(url: destination)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 1.0) < 0.15, "expected roughly a one second clip, got \(duration)")

        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(size == CGSize(width: 160, height: 120))

        #expect(progress.isMonotonic)
        #expect(progress.last == 1)
    }

    @Test("Exporting to HEVC produces a playable movie")
    func exportsHEVC() async throws {
        let source = try await makeSourceVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let destination = TemporaryFiles.newExportURL(fileExtension: "mp4")
        defer { try? FileManager.default.removeItem(at: destination) }

        let options = ExportOptions(
            format: .hevc,
            startTime: 0,
            endTime: 1,
            size: Self.sourceSize,
            frameRate: 30,
            isMuted: true,
            loops: false
        )

        try await Exporter.export(source: source, to: destination, options: options) { _ in }

        let asset = AVURLAsset(url: destination)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let formats = try await track.load(.formatDescriptions)
        let codecs = formats.map { CMFormatDescriptionGetMediaSubType($0) }
        #expect(codecs.contains { $0 == kCMVideoCodecType_HEVC })
    }

    @Test("Exporting to GIF writes one frame per requested interval")
    func exportsGIF() async throws {
        let source = try await makeSourceVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let destination = TemporaryFiles.newExportURL(fileExtension: "gif")
        defer { try? FileManager.default.removeItem(at: destination) }

        let options = ExportOptions(
            format: .gif,
            startTime: 0,
            endTime: 1,
            size: CGSize(width: 160, height: 120),
            frameRate: 10,
            isMuted: true,
            loops: true
        )

        try await Exporter.export(source: source, to: destination, options: options) { _ in }

        let imageSource = try #require(CGImageSourceCreateWithURL(destination as CFURL, nil))
        #expect(CGImageSourceGetCount(imageSource) == 10)

        // Loop count is a container property rather than a per-frame one.
        let properties = CGImageSourceCopyProperties(imageSource, nil) as? [CFString: Any]
        let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let loopCount = gifProperties?[kCGImagePropertyGIFLoopCount] as? Int
        #expect(loopCount == 0, "looping GIFs use a loop count of zero")
    }

    @Test("Exporting to APNG writes an animated PNG")
    func exportsAPNG() async throws {
        let source = try await makeSourceVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let destination = TemporaryFiles.newExportURL(fileExtension: "apng")
        defer { try? FileManager.default.removeItem(at: destination) }

        let options = ExportOptions(
            format: .apng,
            startTime: 0,
            endTime: 0.5,
            size: CGSize(width: 80, height: 60),
            frameRate: 10,
            isMuted: true,
            loops: false
        )

        try await Exporter.export(source: source, to: destination, options: options) { _ in }

        let imageSource = try #require(CGImageSourceCreateWithURL(destination as CFURL, nil))
        #expect(CGImageSourceGetCount(imageSource) == 5)
    }

    @Test("An empty trim range is rejected before any file is created")
    func rejectsEmptyRange() async throws {
        let source = try await makeSourceVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let destination = TemporaryFiles.newExportURL(fileExtension: "mp4")
        let options = ExportOptions(
            format: .mp4,
            startTime: 1,
            endTime: 1,
            size: Self.sourceSize,
            frameRate: 30,
            isMuted: true,
            loops: false
        )

        await #expect(throws: ExportError.emptyTrimRange) {
            try await Exporter.export(source: source, to: destination, options: options) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)))
    }

    @Test("Frame times are evenly spaced across the trim range")
    func frameTimeSpacing() {
        let times = AnimatedImageExporter.frameTimes(from: 1, to: 2, delay: 0.1)
        #expect(times.count == 10)
        #expect(abs(times[0].seconds - 1.0) < 0.001)
        #expect(abs(times[9].seconds - 1.9) < 0.001)
        #expect(AnimatedImageExporter.frameTimes(from: 2, to: 1, delay: 0.1).isEmpty)
    }

    // MARK: - Fixtures

    /// Writes a short clip whose frames change colour, so encoders cannot collapse
    /// the whole thing into a single still.
    private func makeSourceVideo() async throws -> URL {
        let url = TemporaryFiles.newExportURL(fileExtension: "mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(Self.sourceSize.width),
                AVVideoHeightKey: Int(Self.sourceSize.height)
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(Self.sourceSize.width),
                kCVPixelBufferHeightKey as String: Int(Self.sourceSize.height)
            ]
        )

        #expect(writer.canAdd(input))
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(Self.sourceDuration * Double(Self.sourceFrameRate))
        for index in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let buffer = try makePixelBuffer(brightness: UInt8(index * 255 / frameCount))
            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(Self.sourceFrameRate))
            #expect(adaptor.append(buffer, withPresentationTime: time))
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        guard writer.status == .completed else {
            Issue.record("fixture writer failed: \(writer.error?.localizedDescription ?? "unknown")")
            throw ExportError.writeFailed("fixture")
        }
        return url
    }

    private func makePixelBuffer(brightness: UInt8) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(Self.sourceSize.width),
            Int(Self.sourceSize.height),
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw ExportError.writeFailed("could not allocate a pixel buffer")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let length = CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer)
            memset(base, Int32(brightness), length)
        }
        return buffer
    }
}

/// Collects progress callbacks from encoder threads for assertions on the main actor.
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []

    func record(_ value: Double) {
        lock.withLock { values.append(value) }
    }

    var last: Double? {
        lock.withLock { values.last }
    }

    var isMonotonic: Bool {
        lock.withLock {
            zip(values, values.dropFirst()).allSatisfy { $0 <= $1 + 0.0001 }
        }
    }
}

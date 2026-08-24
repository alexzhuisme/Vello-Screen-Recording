import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Testing
import VelloCore
@testable import VelloCapture

@Suite("Webcam compositor")
struct WebcamCompositorTests {
    @Test("A circular camera image is blended into a screen frame")
    func compositesCameraFrame() throws {
        let size = CGSize(width: 320, height: 240)
        let screen = try makeSampleBuffer(width: 320, height: 240, bgra: (255, 0, 0, 255))
        let camera = try makePixelBuffer(width: 160, height: 120, bgra: (0, 0, 255, 255))
        let configuration = WebcamConfiguration(
            deviceID: "test-camera",
            position: .bottomRight,
            size: .medium
        )
        let compositor = WebcamCompositor(configuration: configuration, canvasSize: size)

        let output = try #require(compositor.composite(screen: screen, webcam: camera))
        let pixelBuffer = try #require(CMSampleBufferGetImageBuffer(output))
        let colors = colorCounts(in: pixelBuffer)

        #expect(colors.blue > 40_000, "most of the original blue screen should remain")
        #expect(colors.red > 1_000, "the red camera bubble should be visible")
    }

    @Test("Composed camera frames encode into a playable movie")
    func encodesComposedFrames() async throws {
        let size = CGSize(width: 640, height: 360)
        let camera = try makePixelBuffer(width: 160, height: 120, bgra: (0, 0, 255, 255))
        let configuration = WebcamConfiguration(
            deviceID: "test-camera",
            position: .bottomRight,
            size: .medium
        )
        let compositor = WebcamCompositor(configuration: configuration, canvasSize: size)
        let url = TemporaryFiles.newRecordingURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try SampleWriter(
            url: url,
            pixelSize: size,
            frameRate: 30,
            includesSystemAudio: false,
            includesMicrophone: false
        )

        for frameIndex in 0..<12 {
            let timestamp = CMTime(value: CMTimeValue(frameIndex), timescale: 30)
            let screen = try makeSampleBuffer(
                width: 640,
                height: 360,
                bgra: (255, 0, 0, 255),
                presentationTimeStamp: timestamp
            )
            let composed = try #require(compositor.composite(screen: screen, webcam: camera))
            writer.queue.sync { writer.appendVideo(composed) }
        }

        let outputURL = try await writer.finish()
        let asset = AVURLAsset(url: outputURL)
        let videoTrack = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await videoTrack.load(.naturalSize) == size)
    }

    private func makeSampleBuffer(
        width: Int,
        height: Int,
        bgra: (UInt8, UInt8, UInt8, UInt8),
        presentationTimeStamp: CMTime = .zero
    ) throws -> CMSampleBuffer {
        let pixelBuffer = try makePixelBuffer(width: width, height: height, bgra: bgra)
        var description: CMVideoFormatDescription?
        #expect(CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &description
        ) == noErr)
        let format = try #require(description)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        #expect(CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        ) == noErr)
        return try #require(sample)
    }

    private func makePixelBuffer(
        width: Int,
        height: Int,
        bgra: (UInt8, UInt8, UInt8, UInt8)
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
            &buffer
        ) == kCVReturnSuccess)
        let pixelBuffer = try #require(buffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let base = try #require(CVPixelBufferGetBaseAddress(pixelBuffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                row[offset] = bgra.0
                row[offset + 1] = bgra.1
                row[offset + 2] = bgra.2
                row[offset + 3] = bgra.3
            }
        }
        return pixelBuffer
    }

    private func colorCounts(in pixelBuffer: CVPixelBuffer) -> (blue: Int, red: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return (0, 0) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var blue = 0
        var red = 0
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                if row[offset] > 200, row[offset + 2] < 50 { blue += 1 }
                if row[offset + 2] > 200, row[offset] < 50 { red += 1 }
            }
        }
        return (blue, red)
    }
}

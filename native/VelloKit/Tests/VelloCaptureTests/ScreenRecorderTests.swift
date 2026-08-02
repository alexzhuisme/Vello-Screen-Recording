import AVFoundation
import AppKit
import CoreMedia
import Foundation
import Testing
import VelloCore
@testable import VelloCapture

/// Drives a real `SCStream` capture. Skipped automatically when the test runner
/// has not been granted Screen Recording permission.
@MainActor
@Suite("ScreenRecorder", .serialized)
struct ScreenRecorderTests {
    /// Evaluated by the `.enabled(if:)` traits below so the capture tests are
    /// skipped with a clear reason rather than failing on an unprepared machine.
    nonisolated static var canCapture: Bool { Permissions.hasScreenRecordingAccess }

    private func makeConfiguration(cropRect: CGRect?) throws -> RecordingConfiguration {
        let displayID = try #require(NSScreen.main?.displayID, "no main display")
        return RecordingConfiguration(
            displayID: displayID,
            cropRect: cropRect,
            frameRate: 30,
            showsCursor: false,
            audioDeviceID: nil
        )
    }

    @Test(
        "A short capture writes a playable movie at the cropped size",
        .enabled(if: canCapture, "Screen Recording permission is not granted")
    )
    func recordsCroppedRegion() async throws {
        let recorder = ScreenRecorder()
        let cropRect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let configuration = try makeConfiguration(cropRect: cropRect)

        try await recorder.start(configuration)
        #expect(recorder.state == .recording)

        try await Task.sleep(for: .milliseconds(1200))

        let recording = try await recorder.stop()
        defer { try? FileManager.default.removeItem(at: recording.url) }

        #expect(recorder.state == .idle)
        #expect(FileManager.default.fileExists(atPath: recording.url.path(percentEncoded: false)))

        let asset = AVURLAsset(url: recording.url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        #expect(size.width == cropRect.width * scale)
        #expect(size.height == cropRect.height * scale)

        let duration = try await asset.load(.duration).seconds
        #expect(duration > 0.4, "expected roughly a second of video, got \(duration)")
    }

    @Test(
        "Pausing removes the paused span from the recorded timeline",
        .enabled(if: canCapture, "Screen Recording permission is not granted")
    )
    func pauseShortensOutput() async throws {
        let recorder = ScreenRecorder()
        try await recorder.start(try makeConfiguration(cropRect: CGRect(x: 0, y: 0, width: 320, height: 240)))

        try await Task.sleep(for: .milliseconds(600))
        recorder.pause()
        #expect(recorder.state == .paused)

        // Nothing should be captured across this span.
        try await Task.sleep(for: .milliseconds(1000))

        recorder.resume()
        #expect(recorder.state == .recording)
        try await Task.sleep(for: .milliseconds(600))

        let elapsed = recorder.elapsed
        let recording = try await recorder.stop()
        defer { try? FileManager.default.removeItem(at: recording.url) }

        // The timeline excludes the pause, so about 1.2s of the 2.2s wall clock.
        #expect(elapsed < 1.8, "timeline should exclude the pause, got \(elapsed)")

        let duration = try await AVURLAsset(url: recording.url).load(.duration).seconds
        #expect(duration < 1.8, "output should exclude the pause, got \(duration)")
    }

    @Test(
        "Starting twice is rejected",
        .enabled(if: canCapture, "Screen Recording permission is not granted")
    )
    func rejectsConcurrentRecordings() async throws {
        let recorder = ScreenRecorder()
        let configuration = try makeConfiguration(cropRect: CGRect(x: 0, y: 0, width: 320, height: 240))
        try await recorder.start(configuration)

        await #expect(throws: RecordingError.alreadyRecording) {
            try await recorder.start(configuration)
        }

        let recording = try await recorder.stop()
        try? FileManager.default.removeItem(at: recording.url)
    }

    @Test("Stopping without recording reports that nothing is in progress")
    func stopWithoutStart() async {
        let recorder = ScreenRecorder()
        await #expect(throws: RecordingError.notRecording) {
            _ = try await recorder.stop()
        }
    }

    @Test(
        "Cancelling discards the capture instead of producing a recording",
        .enabled(if: canCapture, "Screen Recording permission is not granted")
    )
    func cancelDiscards() async throws {
        let recorder = ScreenRecorder()
        try await recorder.start(try makeConfiguration(cropRect: CGRect(x: 0, y: 0, width: 320, height: 240)))
        try await Task.sleep(for: .milliseconds(400))

        await recorder.cancel()
        #expect(recorder.state == .idle)

        await #expect(throws: RecordingError.notRecording) {
            _ = try await recorder.stop()
        }
    }
}

import AVFoundation
import AppKit
import AudioToolbox
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
    nonisolated static var canCaptureCamera: Bool {
        Permissions.cameraStatus == .granted && CaptureDevices.defaultVideoInputDevice() != nil
    }

    private func makeConfiguration(
        cropRect: CGRect?,
        audioMode: AudioCaptureMode = .off
    ) throws -> RecordingConfiguration {
        let displayID = try #require(NSScreen.main?.displayID, "no main display")
        return RecordingConfiguration(
            target: .display(displayID: displayID, cropRect: cropRect),
            frameRate: 30,
            showsCursor: false,
            audioMode: audioMode,
            audioDeviceID: nil
        )
    }

    @Test("Stream configuration enables exactly the selected audio sources")
    func configuresAudioSources() {
        let target = CaptureTarget.display(displayID: 1, cropRect: nil)
        let size = CGSize(width: 320, height: 240)

        let off = ScreenRecorder.makeStreamConfiguration(
            RecordingConfiguration(target: target),
            pixelSize: size,
            sourceRect: nil
        )
        #expect(!off.capturesAudio)
        #expect(!off.captureMicrophone)
        #expect(off.excludesCurrentProcessAudio)

        let system = ScreenRecorder.makeStreamConfiguration(
            RecordingConfiguration(target: target, audioMode: .systemAudio),
            pixelSize: size,
            sourceRect: nil
        )
        #expect(system.capturesAudio)
        #expect(!system.captureMicrophone)
        #expect(system.sampleRate == 48_000)
        #expect(system.channelCount == 2)

        let microphone = ScreenRecorder.makeStreamConfiguration(
            RecordingConfiguration(
                target: target,
                audioMode: .microphone,
                audioDeviceID: "input-device"
            ),
            pixelSize: size,
            sourceRect: nil
        )
        #expect(!microphone.capturesAudio)
        #expect(microphone.captureMicrophone)
        #expect(microphone.microphoneCaptureDeviceID == "input-device")

        let both = ScreenRecorder.makeStreamConfiguration(
            RecordingConfiguration(
                target: target,
                audioMode: .systemAudioAndMicrophone,
                audioDeviceID: "input-device"
            ),
            pixelSize: size,
            sourceRect: nil
        )
        #expect(both.capturesAudio)
        #expect(both.captureMicrophone)
    }

    @Test("The capture writer remains healthy with the live dual-audio configuration")
    func createsDualAudioWriter() async throws {
        let url = TemporaryFiles.newRecordingURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try SampleWriter(
            url: url,
            pixelSize: CGSize(width: 1996, height: 1122),
            frameRate: 60,
            includesSystemAudio: true,
            includesMicrophone: true,
            microphoneFormatDescription: try makeMonoAudioDescription()
        )

        // Some AVAssetWriter configuration errors are reported asynchronously
        // shortly after startWriting(), rather than by startWriting() itself.
        try await Task.sleep(for: .milliseconds(200))
        do {
            _ = try await writer.finish()
            Issue.record("an empty writer unexpectedly completed")
        } catch let error as RecordingError {
            #expect(error == .emptyRecording, "writer configuration failed: \(error)")
        }
    }

    @Test("Microphone AAC settings follow a mono native device format")
    func matchesNativeMicrophoneFormat() throws {
        let settings = SampleWriter.audioOutputSettings(
            sourceFormatHint: try makeMonoAudioDescription(),
            fallbackSampleRate: 44_100,
            fallbackChannelCount: 2
        )
        #expect(settings[AVNumberOfChannelsKey] as? Int == 1)
        #expect(settings[AVSampleRateKey] as? Double == 48_000)
    }

    private func makeMonoAudioDescription() throws -> CMAudioFormatDescription {
        var description = AudioStreamBasicDescription(
            mSampleRate: 48_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        var formatDescription: CMAudioFormatDescription?
        #expect(CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &description,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        ) == noErr)
        return try #require(formatDescription)
    }

    @Test(
        "The selected camera produces live frames",
        .enabled(if: canCaptureCamera, "Camera permission is not granted")
    )
    func receivesCameraFrame() async throws {
        let device = try #require(CaptureDevices.defaultVideoInputDevice())
        let capture = try WebcamCapture(deviceID: device.id)
        capture.start()
        defer { capture.stop() }

        for _ in 0..<20 where capture.currentPixelBuffer() == nil {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(capture.currentPixelBuffer() != nil)
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
        "System audio capture writes an audio track",
        .enabled(if: canCapture, "Screen & System Audio Recording permission is not granted")
    )
    func recordsSystemAudio() async throws {
        let recorder = ScreenRecorder()
        let configuration = try makeConfiguration(
            cropRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            audioMode: .systemAudio
        )

        try await recorder.start(configuration)
        try await Task.sleep(for: .milliseconds(1200))

        let recording = try await recorder.stop()
        defer { try? FileManager.default.removeItem(at: recording.url) }

        let audioTracks = try await AVURLAsset(url: recording.url).loadTracks(withMediaType: .audio)
        #expect(audioTracks.count == 1)
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

        // Give ScreenCaptureKit time to deliver at least one complete frame.
        try await Task.sleep(for: .milliseconds(250))
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

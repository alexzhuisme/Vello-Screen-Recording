import AVFoundation
import CoreMedia
import VelloCore

/// Owns the `AVAssetWriter` and all pause bookkeeping.
///
/// Every member is confined to `queue`, which is also the sample handler queue
/// handed to `SCStream`, so incoming buffers are already correctly isolated.
final class SampleWriter: @unchecked Sendable {
    let queue = DispatchQueue(label: "app.vello.capture.writer", qos: .userInitiated)

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?

    private var didStartSession = false
    private var isPaused = false
    private var videoSampleCount = 0

    /// Timestamp where the current pause began, in the stream's own timebase.
    private var pauseStart: CMTime?
    /// Total time spent paused so far, subtracted from every subsequent buffer.
    private var pauseOffset: CMTime = .zero
    /// Last timestamp seen, used to measure the pause gap on resume.
    private var lastSourceTime: CMTime = .zero

    init(url: URL, pixelSize: CGSize, frameRate: Int, includesAudio: Bool) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)

        videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: Self.bitRate(width: width, height: height, frameRate: frameRate),
                    AVVideoMaxKeyFrameIntervalKey: frameRate * 2,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoAllowFrameReorderingKey: false
                ]
            ]
        )
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else {
            throw RecordingError.writerFailed("the video input was rejected")
        }
        writer.add(videoInput)

        if includesAudio {
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 48_000,
                    AVEncoderBitRateKey: 128_000
                ]
            )
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else {
                throw RecordingError.writerFailed("the audio input was rejected")
            }
            writer.add(input)
            audioInput = input
        } else {
            audioInput = nil
        }

        guard writer.startWriting() else {
            throw RecordingError.writerFailed(writer.error?.localizedDescription ?? "could not start writing")
        }
    }

    /// Rough target derived from frame area and rate, clamped to sane bounds.
    private static func bitRate(width: Int, height: Int, frameRate: Int) -> Int {
        let estimate = Double(width * height * frameRate) * 0.11
        return Int(min(max(estimate, 2_000_000), 50_000_000))
    }

    // MARK: - Sample intake (called on `queue`)

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard sourceTime.isValid else { return }
        lastSourceTime = sourceTime

        guard !isPaused else {
            if pauseStart == nil { pauseStart = sourceTime }
            return
        }
        guard writer.status == .writing else { return }

        guard let adjusted = SampleBufferTiming.copy(sampleBuffer, shiftedBy: pauseOffset) else { return }
        let adjustedTime = CMSampleBufferGetPresentationTimeStamp(adjusted)

        if !didStartSession {
            writer.startSession(atSourceTime: adjustedTime)
            didStartSession = true
        }

        guard videoInput.isReadyForMoreMediaData else { return }
        if videoInput.append(adjusted) {
            videoSampleCount += 1
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let audioInput else { return }
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard sourceTime.isValid else { return }

        // Audio before the first video frame has nowhere to land on the timeline.
        guard !isPaused, didStartSession, writer.status == .writing else { return }
        guard let adjusted = SampleBufferTiming.copy(sampleBuffer, shiftedBy: pauseOffset) else { return }
        guard audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(adjusted)
    }

    // MARK: - Control

    func setPaused(_ paused: Bool) {
        queue.async {
            guard paused != self.isPaused else { return }
            if paused {
                self.isPaused = true
                self.pauseStart = nil
            } else {
                // Fold the gap into the running offset so the output stays continuous.
                if let pauseStart = self.pauseStart, self.lastSourceTime > pauseStart {
                    self.pauseOffset = self.pauseOffset + (self.lastSourceTime - pauseStart)
                }
                self.pauseStart = nil
                self.isPaused = false
            }
        }
    }

    func finish() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.videoSampleCount > 0, self.didStartSession else {
                    self.writer.cancelWriting()
                    continuation.resume(throwing: RecordingError.emptyRecording)
                    return
                }

                self.videoInput.markAsFinished()
                self.audioInput?.markAsFinished()

                // The completion handler fires on an arbitrary queue, so hop back
                // to ours before touching the writer again.
                self.writer.finishWriting { [self] in
                    queue.async {
                        if self.writer.status == .completed {
                            continuation.resume(returning: self.writer.outputURL)
                        } else {
                            continuation.resume(
                                throwing: RecordingError.writerFailed(
                                    self.writer.error?.localizedDescription ?? "the writer did not complete"
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    func cancel() {
        queue.async {
            if self.writer.status == .writing {
                self.writer.cancelWriting()
            }
        }
    }
}

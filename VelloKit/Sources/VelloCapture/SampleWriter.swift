import AVFoundation
import CoreMedia
import VelloCore

/// Owns the `AVAssetWriter` and all pause bookkeeping.
///
/// Every member is confined to `queue`, which is also the sample handler queue
/// handed to `SCStream`, so incoming buffers are already correctly isolated.
final class SampleWriter: @unchecked Sendable {
    let queue = DispatchQueue(label: "com.yueming.Vello.capture.writer", qos: .userInitiated)

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let systemAudioInput: AVAssetWriterInput?
    private let microphoneInput: AVAssetWriterInput?

    private var didStartSession = false
    private var sessionStartTime: CMTime?
    private var systemAudioTimeOffset: CMTime?
    private var microphoneTimeOffset: CMTime?
    private var isPaused = false
    private var videoSampleCount = 0

    /// Timestamp where the current pause began, in the stream's own timebase.
    private var pauseStart: CMTime?
    /// Total time spent paused so far, subtracted from every subsequent buffer.
    private var pauseOffset: CMTime = .zero
    /// Last timestamp seen, used to measure the pause gap on resume.
    private var lastSourceTime: CMTime = .zero

    init(
        url: URL,
        pixelSize: CGSize,
        frameRate: Int,
        includesSystemAudio: Bool,
        includesMicrophone: Bool,
        microphoneFormatDescription: CMFormatDescription? = nil
    ) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)

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

        systemAudioInput = try Self.addAudioInput(
            to: writer,
            enabled: includesSystemAudio,
            sourceName: "system audio",
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 48_000,
                AVEncoderBitRateKey: 128_000
            ],
            sourceFormatHint: nil
        )
        microphoneInput = try Self.addAudioInput(
            to: writer,
            enabled: includesMicrophone,
            sourceName: "microphone",
            outputSettings: Self.audioOutputSettings(
                sourceFormatHint: microphoneFormatDescription,
                fallbackSampleRate: 48_000,
                fallbackChannelCount: 1
            ),
            sourceFormatHint: microphoneFormatDescription
        )

        guard writer.startWriting() else {
            throw RecordingError.writerFailed(
                Self.failureReason(writer.error, fallback: "could not start writing")
            )
        }
    }

    /// Rough target derived from frame area and rate, clamped to sane bounds.
    private static func bitRate(width: Int, height: Int, frameRate: Int) -> Int {
        let estimate = Double(width * height * frameRate) * 0.11
        return Int(min(max(estimate, 2_000_000), 50_000_000))
    }

    private static func addAudioInput(
        to writer: AVAssetWriter,
        enabled: Bool,
        sourceName: String,
        outputSettings: [String: Any],
        sourceFormatHint: CMFormatDescription?
    ) throws -> AVAssetWriterInput? {
        guard enabled else { return nil }

        // Preserve the selected microphone's native format when one is known.
        // System audio already has a fixed format from the stream configuration.
        let input: AVAssetWriterInput
        if let sourceFormatHint {
            input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: outputSettings,
                sourceFormatHint: sourceFormatHint
            )
        } else {
            input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: outputSettings
            )
        }
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw RecordingError.writerFailed("the \(sourceName) input was rejected")
        }
        writer.add(input)
        return input
    }

    /// Matches the AAC track to the native microphone format. ScreenCaptureKit's
    /// system-audio output is configured by us (48 kHz stereo), but microphone
    /// output follows the selected hardware and is commonly mono.
    static func audioOutputSettings(
        sourceFormatHint: CMFormatDescription?,
        fallbackSampleRate: Double,
        fallbackChannelCount: Int
    ) -> [String: Any] {
        let basicDescription = sourceFormatHint.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        }
        let nativeSampleRate = basicDescription?.mSampleRate ?? fallbackSampleRate
        let sampleRate = nativeSampleRate.isFinite && nativeSampleRate > 0
            ? nativeSampleRate
            : fallbackSampleRate
        let nativeChannelCount = Int(basicDescription?.mChannelsPerFrame ?? 0)
        let channelCount = nativeChannelCount > 0 ? nativeChannelCount : fallbackChannelCount

        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: channelCount,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: 128_000
        ]
    }

    private static func failureReason(_ error: Error?, fallback: String) -> String {
        guard let error = error as NSError? else { return fallback }
        var reason = "\(error.localizedDescription) (\(error.domain) \(error.code))"
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            reason += "; underlying \(underlying.domain) \(underlying.code)"
        }
        return reason
    }

    /// AVAssetWriter may transition to `.failed` asynchronously after
    /// `startWriting()` has already returned true. The stream adapter polls this
    /// on its serial sample queue so capture can stop at the first failed frame
    /// instead of waiting for the user to press Stop.
    func failureIfAny() -> RecordingError? {
        guard writer.status == .failed else { return nil }
        return .writerFailed(
            Self.failureReason(
                writer.error,
                fallback: "the writer failed while recording"
            )
        )
    }

    // MARK: - Sample intake (called on `queue`)

    /// Tracks every screen timestamp, including idle buffers with no new image.
    /// AVAssetWriter can then preserve elapsed time by ending the session at the
    /// final observed timestamp instead of the final changed frame.
    func observeVideoTime(_ sampleBuffer: CMSampleBuffer) {
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard sourceTime.isValid else { return }
        lastSourceTime = sourceTime
        if isPaused, pauseStart == nil {
            pauseStart = sourceTime
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard sourceTime.isValid else { return }
        observeVideoTime(sampleBuffer)

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
            sessionStartTime = adjustedTime
        }

        guard videoInput.isReadyForMoreMediaData else { return }
        if videoInput.append(adjusted) {
            videoSampleCount += 1
        }
    }

    func appendSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        systemAudioTimeOffset = appendAudio(
            sampleBuffer,
            to: systemAudioInput,
            sourceTimeOffset: systemAudioTimeOffset
        )
    }

    func appendMicrophoneAudio(_ sampleBuffer: CMSampleBuffer) {
        microphoneTimeOffset = appendAudio(
            sampleBuffer,
            to: microphoneInput,
            sourceTimeOffset: microphoneTimeOffset
        )
    }

    @discardableResult
    private func appendAudio(
        _ sampleBuffer: CMSampleBuffer,
        to audioInput: AVAssetWriterInput?,
        sourceTimeOffset: CMTime?
    ) -> CMTime? {
        guard let audioInput else { return sourceTimeOffset }
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard sourceTime.isValid else { return sourceTimeOffset }

        // Audio before the first video frame has nowhere to land on the timeline.
        guard !isPaused,
              didStartSession,
              let sessionStartTime,
              writer.status == .writing
        else { return sourceTimeOffset }

        // Microphone buffers use the device's clock, which may not share the
        // screen stream's epoch. Align the first sample from each audio source to
        // the first video frame, then apply the normal pause offset.
        let resolvedSourceOffset = sourceTimeOffset ?? (sourceTime - sessionStartTime)
        let totalOffset = resolvedSourceOffset + pauseOffset
        guard let adjusted = SampleBufferTiming.copy(sampleBuffer, shiftedBy: totalOffset) else {
            return resolvedSourceOffset
        }
        guard audioInput.isReadyForMoreMediaData else { return resolvedSourceOffset }
        audioInput.append(adjusted)
        return resolvedSourceOffset
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
                if self.writer.status == .failed {
                    continuation.resume(
                        throwing: RecordingError.writerFailed(
                            Self.failureReason(
                                self.writer.error,
                                fallback: "the writer failed before receiving video"
                            )
                        )
                    )
                    return
                }

                guard self.videoSampleCount > 0, self.didStartSession else {
                    self.writer.cancelWriting()
                    continuation.resume(throwing: RecordingError.emptyRecording)
                    return
                }

                if let startTime = self.sessionStartTime {
                    var effectiveOffset = self.pauseOffset
                    if self.isPaused,
                       let pauseStart = self.pauseStart,
                       self.lastSourceTime > pauseStart {
                        effectiveOffset = effectiveOffset + (self.lastSourceTime - pauseStart)
                    }
                    let endTime = self.lastSourceTime - effectiveOffset
                    if endTime > startTime {
                        self.writer.endSession(atSourceTime: endTime)
                    }
                }

                self.videoInput.markAsFinished()
                self.systemAudioInput?.markAsFinished()
                self.microphoneInput?.markAsFinished()

                // The completion handler fires on an arbitrary queue, so hop back
                // to ours before touching the writer again.
                self.writer.finishWriting { [self] in
                    queue.async {
                        if self.writer.status == .completed {
                            continuation.resume(returning: self.writer.outputURL)
                        } else {
                            continuation.resume(
                                throwing: RecordingError.writerFailed(
                                    Self.failureReason(
                                        self.writer.error,
                                        fallback: "the writer did not complete"
                                    )
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

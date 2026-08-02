import AVFoundation
import AppKit
import CoreMedia
import Observation
import ScreenCaptureKit
import VelloCore

/// Bridges `SCStream`'s non-isolated callbacks into the queue-confined writer.
private final class StreamOutputAdapter: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let writer: SampleWriter
    private let onStop: @Sendable (Error) -> Void

    init(writer: SampleWriter, onStop: @escaping @Sendable (Error) -> Void) {
        self.writer = writer
        self.onStop = onStop
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        switch type {
        case .screen:
            // Idle frames repeat the previous image and carry no new content.
            guard Self.isCompleteFrame(sampleBuffer) else { return }
            writer.appendVideo(sampleBuffer)
        case .microphone:
            writer.appendAudio(sampleBuffer)
        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop(error)
    }

    private static func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
            let raw = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: raw)
        else { return false }

        return status == .complete
    }
}

@MainActor
@Observable
public final class ScreenRecorder {
    public private(set) var state: RecordingState = .idle
    public private(set) var timeline = RecordingTimeline()

    /// Called when capture stops on its own, for example if the display is unplugged.
    @ObservationIgnored
    public var onUnexpectedStop: ((Error) -> Void)?

    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private var writer: SampleWriter?
    @ObservationIgnored private var adapter: StreamOutputAdapter?
    @ObservationIgnored private var configuration: RecordingConfiguration?

    public init() {}

    public var elapsed: TimeInterval { timeline.elapsed() }

    // MARK: - Lifecycle

    public func start(_ configuration: RecordingConfiguration) async throws {
        guard state == .idle else { throw RecordingError.alreadyRecording }
        guard Permissions.hasScreenRecordingAccess else {
            throw RecordingError.screenRecordingPermissionDenied
        }

        state = .starting

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            guard let display = content.displays.first(where: { $0.displayID == configuration.displayID })
            else { throw RecordingError.displayUnavailable }

            // Keep Vello's own overlay and windows out of the capture.
            let ownApplications = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplications,
                exceptingWindows: []
            )

            let scaleFactor = NSScreen.screens
                .first { $0.displayID == configuration.displayID }?
                .backingScaleFactor ?? 2

            let regionInPoints = configuration.cropRect
                ?? CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
            let pixelSize = CGSize(
                width: Self.evenPixels(regionInPoints.width * scaleFactor),
                height: Self.evenPixels(regionInPoints.height * scaleFactor)
            )

            let outputURL = TemporaryFiles.newRecordingURL()
            let writer = try SampleWriter(
                url: outputURL,
                pixelSize: pixelSize,
                frameRate: configuration.frameRate,
                includesAudio: configuration.recordsAudio
            )

            let adapter = StreamOutputAdapter(writer: writer) { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.handleUnexpectedStop(error)
                }
            }

            let streamConfiguration = Self.makeStreamConfiguration(
                configuration,
                pixelSize: pixelSize,
                regionInPoints: regionInPoints
            )

            let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: adapter)
            try stream.addStreamOutput(adapter, type: .screen, sampleHandlerQueue: writer.queue)
            if configuration.recordsAudio {
                try stream.addStreamOutput(adapter, type: .microphone, sampleHandlerQueue: writer.queue)
            }

            try await stream.startCapture()

            self.stream = stream
            self.writer = writer
            self.adapter = adapter
            self.configuration = configuration
            timeline.start()
            state = .recording

            Log.capture.info("Recording started at \(pixelSize.width, privacy: .public)x\(pixelSize.height, privacy: .public)")
        } catch {
            await teardown()
            state = .idle
            throw error
        }
    }

    public func pause() {
        guard state == .recording else { return }
        writer?.setPaused(true)
        timeline.pause()
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        writer?.setPaused(false)
        timeline.resume()
        state = .recording
    }

    public func stop() async throws -> Recording {
        guard state.isActive, let writer, let configuration else {
            throw RecordingError.notRecording
        }

        state = .stopping
        timeline.pause()

        if let stream {
            try? await stream.stopCapture()
        }
        self.stream = nil

        defer {
            self.writer = nil
            adapter = nil
            self.configuration = nil
            timeline.reset()
            state = .idle
        }

        let url = try await writer.finish()
        return Recording(url: url, configuration: configuration)
    }

    /// Stops without producing a recording and deletes the partial file.
    public func cancel() async {
        guard state != .idle else { return }
        state = .stopping
        await teardown()
        state = .idle
    }

    // MARK: - Helpers

    private func teardown() async {
        if let stream {
            try? await stream.stopCapture()
        }
        writer?.cancel()
        stream = nil
        writer = nil
        adapter = nil
        configuration = nil
        timeline.reset()
    }

    private func handleUnexpectedStop(_ error: Error) {
        guard state.isActive || state == .starting else { return }
        Log.capture.error("Capture stopped unexpectedly: \(error.localizedDescription, privacy: .public)")
        let reported = RecordingError.streamFailed(error.localizedDescription)
        Task { @MainActor in
            await teardown()
            state = .idle
            onUnexpectedStop?(reported)
        }
    }

    private static func makeStreamConfiguration(
        _ configuration: RecordingConfiguration,
        pixelSize: CGSize,
        regionInPoints: CGRect
    ) -> SCStreamConfiguration {
        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.width = Int(pixelSize.width)
        streamConfiguration.height = Int(pixelSize.height)
        streamConfiguration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(configuration.frameRate)
        )
        streamConfiguration.showsCursor = configuration.showsCursor
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.colorSpaceName = CGColorSpace.sRGB
        streamConfiguration.queueDepth = 8
        streamConfiguration.scalesToFit = false
        streamConfiguration.capturesAudio = false

        if configuration.cropRect != nil {
            streamConfiguration.sourceRect = regionInPoints
        }

        if let audioDeviceID = configuration.audioDeviceID {
            streamConfiguration.captureMicrophone = true
            streamConfiguration.microphoneCaptureDeviceID = audioDeviceID
        }

        return streamConfiguration
    }

    /// H.264 requires even dimensions.
    private static func evenPixels(_ value: CGFloat) -> CGFloat {
        let rounded = Int(value.rounded())
        return CGFloat(max(2, rounded - (rounded % 2)))
    }
}

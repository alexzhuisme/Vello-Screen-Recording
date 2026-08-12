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
        case .audio:
            writer.appendSystemAudio(sampleBuffer)
        case .microphone:
            writer.appendMicrophoneAudio(sampleBuffer)
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

    /// - Parameter includedWindowIDs: Windows that should still appear in the
    ///   recording even though the rest of this app is excluded — used for the
    ///   click-highlight overlays. Ignored for window capture targets.
    public func start(
        _ configuration: RecordingConfiguration,
        includedWindowIDs: [CGWindowID] = []
    ) async throws {
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

            let resolved = try Self.resolveCapture(
                configuration.target,
                content: content,
                includedWindowIDs: includedWindowIDs
            )

            let outputURL = TemporaryFiles.newRecordingURL()
            let writer = try SampleWriter(
                url: outputURL,
                pixelSize: resolved.pixelSize,
                frameRate: configuration.frameRate,
                includesSystemAudio: configuration.recordsSystemAudio,
                includesMicrophone: configuration.recordsMicrophone
            )

            let adapter = StreamOutputAdapter(writer: writer) { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.handleUnexpectedStop(error)
                }
            }

            let streamConfiguration = Self.makeStreamConfiguration(
                configuration,
                pixelSize: resolved.pixelSize,
                sourceRect: resolved.sourceRect
            )

            let stream = SCStream(filter: resolved.filter, configuration: streamConfiguration, delegate: adapter)
            try stream.addStreamOutput(adapter, type: .screen, sampleHandlerQueue: writer.queue)
            if configuration.recordsSystemAudio {
                try stream.addStreamOutput(adapter, type: .audio, sampleHandlerQueue: writer.queue)
            }
            if configuration.recordsMicrophone {
                try stream.addStreamOutput(adapter, type: .microphone, sampleHandlerQueue: writer.queue)
            }

            try await stream.startCapture()

            self.stream = stream
            self.writer = writer
            self.adapter = adapter
            self.configuration = configuration
            timeline.start()
            state = .recording

            Log.capture.info(
                "Recording started at \(resolved.pixelSize.width, privacy: .public)x\(resolved.pixelSize.height, privacy: .public)"
            )
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

    private struct ResolvedCapture {
        let filter: SCContentFilter
        let pixelSize: CGSize
        /// Display-local source rect for region capture; `nil` for window / full display.
        let sourceRect: CGRect?
    }

    private static func resolveCapture(
        _ target: CaptureTarget,
        content: SCShareableContent,
        includedWindowIDs: [CGWindowID]
    ) throws -> ResolvedCapture {
        switch target {
        case let .display(displayID, cropRect):
            guard let display = content.displays.first(where: { $0.displayID == displayID })
            else { throw RecordingError.displayUnavailable }

            // Keep Vello's own overlay and windows out of the capture, except for
            // any click-highlight windows the caller asked to include.
            let ownApplications = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let includedWindows = content.windows.filter { includedWindowIDs.contains($0.windowID) }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplications,
                exceptingWindows: includedWindows
            )

            let scaleFactor = NSScreen.screens
                .first { $0.displayID == displayID }?
                .backingScaleFactor ?? 2

            let regionInPoints = cropRect
                ?? CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
            let pixelSize = CGSize(
                width: evenPixels(regionInPoints.width * scaleFactor),
                height: evenPixels(regionInPoints.height * scaleFactor)
            )

            return ResolvedCapture(
                filter: filter,
                pixelSize: pixelSize,
                sourceRect: cropRect != nil ? regionInPoints : nil
            )

        case let .window(windowID):
            guard let window = content.windows.first(where: { $0.windowID == windowID })
            else { throw RecordingError.windowUnavailable }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let scaleFactor = scaleFactor(for: window.frame)
            let pixelSize = CGSize(
                width: evenPixels(window.frame.width * scaleFactor),
                height: evenPixels(window.frame.height * scaleFactor)
            )

            return ResolvedCapture(filter: filter, pixelSize: pixelSize, sourceRect: nil)
        }
    }

    private static func scaleFactor(for globalFrame: CGRect) -> CGFloat {
        let center = CGPoint(x: globalFrame.midX, y: globalFrame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.main
        return screen?.backingScaleFactor ?? 2
    }

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

    static func makeStreamConfiguration(
        _ configuration: RecordingConfiguration,
        pixelSize: CGSize,
        sourceRect: CGRect?
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
        streamConfiguration.capturesAudio = configuration.recordsSystemAudio
        streamConfiguration.sampleRate = 48_000
        streamConfiguration.channelCount = 2
        // Prevent Vello's editor or UI sounds from feeding back into a capture.
        streamConfiguration.excludesCurrentProcessAudio = true

        if let sourceRect {
            streamConfiguration.sourceRect = sourceRect
        }

        if configuration.recordsMicrophone, let audioDeviceID = configuration.audioDeviceID {
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

import AVFoundation
import AppKit
import Observation
import VelloCore
import VelloExport

@MainActor
@Observable
final class EditorModel: Identifiable {
    let id = UUID()
    let recording: Recording

    @ObservationIgnored let settings: Settings
    @ObservationIgnored let player = AVPlayer()

    private(set) var duration: TimeInterval = 0
    private(set) var sourceSize: CGSize = .zero
    private(set) var thumbnails: [NSImage] = []
    private(set) var isLoaded = false
    var loadError: String?

    var currentTime: TimeInterval = 0
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval = 0
    var isPlaying = false
    var isMuted = false

    var format: ExportFormat
    var frameRate: Int
    var scalePercent: Int = 100

    var exportJob: ExportJob?

    @ObservationIgnored var onClose: (() -> Void)?

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var asset: AVURLAsset?

    static let scaleOptions = [100, 75, 50, 33, 25]

    init(recording: Recording, settings: Settings) {
        self.recording = recording
        self.settings = settings
        format = settings.defaultExportFormat
        frameRate = recording.configuration.frameRate
    }

    isolated deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    var title: String { recording.defaultFileName }

    var trimmedDuration: TimeInterval { max(0, trimEnd - trimStart) }

    /// Output size in pixels after the scale percentage is applied.
    var exportSize: CGSize {
        let factor = CGFloat(scalePercent) / 100
        return CGSize(
            width: max(2, (sourceSize.width * factor).rounded()),
            height: max(2, (sourceSize.height * factor).rounded())
        )
    }

    var canExport: Bool {
        isLoaded && trimmedDuration > 0.05 && exportJob == nil
    }

    /// GIF and APNG have no audio track, so the mute control does not apply.
    var supportsAudio: Bool {
        format.supportsAudio && recording.configuration.recordsAudio
    }

    // MARK: - Loading

    func load() async {
        let asset = AVURLAsset(url: recording.url)
        self.asset = asset

        do {
            let loadedDuration = try await asset.load(.duration).seconds
            guard loadedDuration.isFinite, loadedDuration > 0 else {
                loadError = "The recording appears to be empty."
                return
            }

            duration = loadedDuration
            trimStart = 0
            trimEnd = loadedDuration

            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let naturalSize = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let displayed = naturalSize.applying(transform)
                sourceSize = CGSize(width: abs(displayed.width), height: abs(displayed.height))
            }

            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            observePlayback()
            isLoaded = true

            await generateThumbnails(for: asset)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func observePlayback() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.03, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                // Playback is confined to the trimmed range so preview matches output.
                if self.isPlaying, self.currentTime >= self.trimEnd - 0.01 {
                    self.seek(to: self.trimStart)
                    self.pause()
                }
            }
        }
    }

    private func generateThumbnails(for asset: AVURLAsset) async {
        let count = 24
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.4, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.4, preferredTimescale: 600)

        let times = (0..<count).map {
            CMTime(seconds: duration * Double($0) / Double(count), preferredTimescale: 600)
        }

        var images: [NSImage] = []
        for await result in generator.images(for: times) {
            guard let cgImage = try? result.image else { continue }
            images.append(NSImage(cgImage: cgImage, size: .zero))
        }
        thumbnails = images
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        if currentTime < trimStart || currentTime >= trimEnd - 0.01 {
            seek(to: trimStart)
        }
        player.isMuted = isMuted
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        let clamped = min(max(time, 0), duration)
        currentTime = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func setTrimStart(_ time: TimeInterval) {
        trimStart = min(max(0, time), trimEnd - 0.1)
        if currentTime < trimStart { seek(to: trimStart) }
    }

    func setTrimEnd(_ time: TimeInterval) {
        trimEnd = max(min(duration, time), trimStart + 0.1)
        if currentTime > trimEnd { seek(to: trimEnd) }
    }

    // MARK: - Export

    func export() {
        guard canExport else { return }
        pause()

        let options = ExportOptions(
            format: format,
            startTime: trimStart,
            endTime: trimEnd,
            size: exportSize,
            frameRate: frameRate,
            isMuted: isMuted || !supportsAudio,
            loops: settings.loopAnimatedExports
        )

        guard let destination = SaveDestination.resolve(
            settings: settings,
            fileName: recording.defaultFileName,
            format: format
        ) else { return }

        settings.defaultExportFormat = format

        let job = ExportJob(
            source: recording.url,
            destination: destination.url,
            options: options,
            accessScope: destination.accessScope
        )
        exportJob = job
        job.start()
    }

    func dismissExport() {
        exportJob = nil
    }

    func cancelExport() {
        exportJob?.cancel()
        exportJob = nil
    }

    /// Removes the temporary capture file once the user is finished with it.
    func discardRecording() {
        pause()
        try? FileManager.default.removeItem(at: recording.url)
    }
}

import CoreMedia
import Foundation
import Testing
import VelloCore
@testable import VelloExport

@Suite("ExportOptions")
struct ExportOptionsTests {
    private func options(
        format: ExportFormat = .mp4,
        start: TimeInterval = 0,
        end: TimeInterval = 10,
        muted: Bool = false
    ) -> ExportOptions {
        ExportOptions(
            format: format,
            startTime: start,
            endTime: end,
            size: CGSize(width: 1280, height: 720),
            frameRate: 30,
            isMuted: muted,
            loops: true
        )
    }

    @Test("Duration reflects the trim range")
    func duration() {
        #expect(options(start: 2, end: 7).duration == 5)
    }

    @Test("An inverted trim range yields zero rather than a negative duration")
    func invertedRange() {
        #expect(options(start: 9, end: 4).duration == 0)
    }

    @Test("The time range converts to CMTime at a 600 timescale")
    func timeRange() {
        let range = options(start: 1.5, end: 4).timeRange
        #expect(range.start == CMTime(value: 900, timescale: 600))
        #expect(range.duration.seconds == 2.5)
    }

    @Test("Muting suppresses audio for video formats")
    func mutedVideo() {
        #expect(options(muted: false).producesAudio)
        #expect(!options(muted: true).producesAudio)
    }

    @Test("Animated image formats never produce audio")
    func animatedImagesHaveNoAudio() {
        #expect(!options(format: .gif).producesAudio)
        #expect(!options(format: .apng).producesAudio)
    }
}

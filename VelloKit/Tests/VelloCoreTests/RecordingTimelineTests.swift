import Foundation
import Testing
@testable import VelloCore

@Suite("RecordingTimeline")
struct RecordingTimelineTests {
    private let origin = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("A fresh timeline reports no elapsed time")
    func startsEmpty() {
        let timeline = RecordingTimeline()
        #expect(timeline.elapsed(at: origin) == 0)
        #expect(!timeline.isRunning)
    }

    @Test("Elapsed time accrues while running")
    func accruesWhileRunning() {
        var timeline = RecordingTimeline()
        timeline.start(at: origin)
        #expect(timeline.isRunning)
        #expect(timeline.elapsed(at: origin.addingTimeInterval(5)) == 5)
    }

    @Test("Time spent paused is excluded")
    func excludesPausedTime() {
        var timeline = RecordingTimeline()
        timeline.start(at: origin)
        timeline.pause(at: origin.addingTimeInterval(10))

        // Ten seconds of wall clock pass while paused.
        #expect(timeline.elapsed(at: origin.addingTimeInterval(20)) == 10)

        timeline.resume(at: origin.addingTimeInterval(20))
        #expect(timeline.elapsed(at: origin.addingTimeInterval(25)) == 15)
    }

    @Test("Repeated pause and resume cycles accumulate correctly")
    func handlesMultipleCycles() {
        var timeline = RecordingTimeline()
        timeline.start(at: origin)
        timeline.pause(at: origin.addingTimeInterval(3))
        timeline.resume(at: origin.addingTimeInterval(8))
        timeline.pause(at: origin.addingTimeInterval(11))
        timeline.resume(at: origin.addingTimeInterval(30))

        #expect(timeline.elapsed(at: origin.addingTimeInterval(32)) == 8)
    }

    @Test("Redundant pause and resume calls are ignored")
    func ignoresRedundantTransitions() {
        var timeline = RecordingTimeline()
        timeline.start(at: origin)
        timeline.pause(at: origin.addingTimeInterval(4))
        timeline.pause(at: origin.addingTimeInterval(9))
        #expect(timeline.elapsed(at: origin.addingTimeInterval(9)) == 4)

        timeline.resume(at: origin.addingTimeInterval(10))
        timeline.resume(at: origin.addingTimeInterval(12))
        #expect(timeline.elapsed(at: origin.addingTimeInterval(14)) == 8)
    }

    @Test("Reset clears accumulated time")
    func resetClears() {
        var timeline = RecordingTimeline()
        timeline.start(at: origin)
        timeline.pause(at: origin.addingTimeInterval(6))
        timeline.reset()
        #expect(timeline.elapsed(at: origin.addingTimeInterval(6)) == 0)
        #expect(!timeline.isRunning)
    }
}

@Suite("Duration formatting")
struct DurationFormattingTests {
    @Test(
        "Durations render as minutes and seconds below an hour",
        arguments: [
            (0.0, "0:00"),
            (5.0, "0:05"),
            (65.0, "1:05"),
            (599.0, "9:59")
        ]
    )
    func formatsShortDurations(interval: TimeInterval, expected: String) {
        #expect(formatDuration(interval) == expected)
    }

    @Test("Durations of an hour or more include hours")
    func formatsLongDurations() {
        #expect(formatDuration(3600) == "1:00:00")
        #expect(formatDuration(3725) == "1:02:05")
    }
}

import Foundation
import Testing
@testable import VelloCore

@MainActor
@Suite("Recording countdown")
struct RecordingCountdownTests {
    @Test("Countdown choices produce descending overlay ticks")
    func tickValues() {
        #expect(RecordingCountdown.off.ticks.isEmpty)
        #expect(RecordingCountdown.threeSeconds.ticks == [3, 2, 1])
        #expect(RecordingCountdown.fiveSeconds.ticks == [5, 4, 3, 2, 1])
    }

    @Test("New settings default to a three-second countdown")
    func defaultValue() throws {
        let suiteName = "VelloTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = Settings(defaults: defaults)
        #expect(settings.recordingCountdown == .threeSeconds)
    }

    @Test("The selected countdown persists")
    func persistsSelectedValue() throws {
        let suiteName = "VelloTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = Settings(defaults: defaults)
        settings.recordingCountdown = .fiveSeconds

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.recordingCountdown == .fiveSeconds)
    }
}

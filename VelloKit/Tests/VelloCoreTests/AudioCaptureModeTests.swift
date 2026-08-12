import Foundation
import Testing
@testable import VelloCore

@MainActor
@Suite("Audio capture modes")
struct AudioCaptureModeTests {
    @Test("Each mode enables the intended sources")
    func sourceFlags() {
        #expect(!AudioCaptureMode.off.recordsAudio)
        #expect(AudioCaptureMode.systemAudio.includesSystemAudio)
        #expect(!AudioCaptureMode.systemAudio.includesMicrophone)
        #expect(!AudioCaptureMode.microphone.includesSystemAudio)
        #expect(AudioCaptureMode.microphone.includesMicrophone)
        #expect(AudioCaptureMode.systemAudioAndMicrophone.includesSystemAudio)
        #expect(AudioCaptureMode.systemAudioAndMicrophone.includesMicrophone)
    }

    @Test("Recording configuration reflects only sources it can actually capture")
    func effectiveConfiguration() {
        let target = CaptureTarget.display(displayID: 1, cropRect: nil)

        let missingMicrophone = RecordingConfiguration(
            target: target,
            audioMode: .microphone,
            audioDeviceID: nil
        )
        #expect(!missingMicrophone.recordsAudio)

        let both = RecordingConfiguration(
            target: target,
            audioMode: .systemAudioAndMicrophone,
            audioDeviceID: "input-device"
        )
        #expect(both.recordsAudio)
        #expect(both.recordsSystemAudio)
        #expect(both.recordsMicrophone)
    }

    @Test("The old microphone preference migrates to microphone mode")
    func migratesLegacyPreference() throws {
        let suiteName = "VelloTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "recordAudio")

        let settings = Settings(defaults: defaults)
        #expect(settings.audioCaptureMode == .microphone)
    }

    @Test("The selected mode persists")
    func persistsSelectedMode() throws {
        let suiteName = "VelloTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = Settings(defaults: defaults)
        settings.audioCaptureMode = .systemAudioAndMicrophone

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.audioCaptureMode == .systemAudioAndMicrophone)
    }
}

import Foundation
import Testing
@testable import VelloCore

@MainActor
@Suite("Save destination settings")
struct SaveDestinationSettingsTests {
    @Test("Downloads is the default save folder")
    func defaultsToDownloads() throws {
        let suiteName = "VelloCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = Settings(defaults: defaults)
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        #expect(settings.resolveSaveDirectory() == downloads)
        #expect(settings.saveDirectoryDisplayName == "Downloads")
        #expect(!settings.asksForSaveLocation)
    }

    @Test("Ask Every Time remains an explicit persistent choice")
    func persistsAskEveryTime() throws {
        let suiteName = "VelloCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = Settings(defaults: defaults)
        settings.askForSaveLocationEveryTime()

        let restored = Settings(defaults: defaults)
        #expect(restored.resolveSaveDirectory() == nil)
        #expect(restored.saveDirectoryDisplayName == "Ask every time")
        #expect(restored.asksForSaveLocation)
    }

    @Test("Reset returns to Downloads")
    func resetsToDownloads() throws {
        let suiteName = "VelloCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = Settings(defaults: defaults)
        settings.askForSaveLocationEveryTime()
        settings.useDownloadsDirectory()

        #expect(settings.resolveSaveDirectory() != nil)
        #expect(settings.saveDirectoryDisplayName == "Downloads")
        #expect(!settings.asksForSaveLocation)
    }
}

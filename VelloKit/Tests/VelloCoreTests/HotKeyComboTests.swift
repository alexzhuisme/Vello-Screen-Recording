import Foundation
import Testing
@testable import VelloCore

@Suite("HotKeyCombo")
struct HotKeyComboTests {
    @Test("The default shortcut matches Kap's Command-Shift-5")
    func defaultShortcut() {
        let combo = HotKeyCombo.defaultToggleCropper
        #expect(combo.hasCommand)
        #expect(combo.hasShift)
        #expect(!combo.hasOption)
        #expect(!combo.hasControl)
        #expect(combo.displayString == "⇧⌘5")
    }

    @Test("A combo without modifiers is rejected")
    func requiresModifier() {
        let bare = HotKeyCombo(keyCode: 0x17, modifierFlags: 0)
        #expect(!bare.isValid)
        #expect(HotKeyCombo.defaultToggleCropper.isValid)
    }

    @Test("Modifier symbols render in the conventional order")
    func modifierOrdering() {
        let combo = HotKeyCombo(
            keyCode: 0x00,
            modifierFlags: HotKeyCombo.controlFlag | HotKeyCombo.optionFlag
                | HotKeyCombo.shiftFlag | HotKeyCombo.commandFlag
        )
        #expect(combo.displayString == "⌃⌥⇧⌘A")
    }

    @Test("Combos survive a round trip through their persisted form")
    func codableRoundTrip() throws {
        let original = HotKeyCombo(keyCode: 0x31, modifierFlags: HotKeyCombo.optionFlag)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotKeyCombo.self, from: data)
        #expect(decoded == original)
        #expect(decoded.displayString == "⌥Space")
    }
}

@Suite("ExportFormat")
struct ExportFormatTests {
    @Test("HEVC and AV-style video formats share the mp4 container")
    func videoExtensions() {
        #expect(ExportFormat.mp4.fileExtension == "mp4")
        #expect(ExportFormat.hevc.fileExtension == "mp4")
    }

    @Test("Animated image formats carry no audio")
    func animatedImageFormats() {
        for format in ExportFormat.allCases where format.isAnimatedImage {
            #expect(!format.supportsAudio)
        }
        #expect(ExportFormat.gif.isAnimatedImage)
        #expect(ExportFormat.apng.isAnimatedImage)
        #expect(!ExportFormat.mp4.isAnimatedImage)
        #expect(ExportFormat.mp4.supportsAudio)
    }
}

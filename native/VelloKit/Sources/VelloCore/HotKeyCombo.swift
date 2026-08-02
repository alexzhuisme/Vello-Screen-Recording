import Foundation

/// A global hotkey expressed with a virtual key code and Cocoa modifier flags.
/// Carbon translation lives in the app layer that registers the hotkey.
public struct HotKeyCombo: Sendable, Equatable, Codable {
    /// Virtual key code (`kVK_*`).
    public var keyCode: UInt16
    /// Raw value of `NSEvent.ModifierFlags`, restricted to the device-independent bits.
    public var modifierFlags: UInt

    public init(keyCode: UInt16, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    public static let commandFlag: UInt = 1 << 20
    public static let shiftFlag: UInt = 1 << 17
    public static let optionFlag: UInt = 1 << 19
    public static let controlFlag: UInt = 1 << 18

    public var hasCommand: Bool { modifierFlags & Self.commandFlag != 0 }
    public var hasShift: Bool { modifierFlags & Self.shiftFlag != 0 }
    public var hasOption: Bool { modifierFlags & Self.optionFlag != 0 }
    public var hasControl: Bool { modifierFlags & Self.controlFlag != 0 }

    /// Matches Kap's historical default of Command-Shift-5.
    public static let defaultToggleCropper = HotKeyCombo(
        keyCode: 0x17, // kVK_ANSI_5
        modifierFlags: commandFlag | shiftFlag
    )

    /// A hotkey without any modifier would swallow ordinary typing.
    public var isValid: Bool {
        modifierFlags & (Self.commandFlag | Self.shiftFlag | Self.optionFlag | Self.controlFlag) != 0
    }

    public var displayString: String {
        var result = ""
        if hasControl { result += "⌃" }
        if hasOption { result += "⌥" }
        if hasShift { result += "⇧" }
        if hasCommand { result += "⌘" }
        result += Self.keyName(for: keyCode)
        return result
    }

    private static func keyName(for keyCode: UInt16) -> String {
        if let name = keyCodeNames[keyCode] { return name }
        return "Key \(keyCode)"
    }

    private static let keyCodeNames: [UInt16: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
        0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
        0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1",
        0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
        0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1F: "O",
        0x20: "U", 0x22: "I", 0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K",
        0x2D: "N", 0x2E: "M", 0x31: "Space", 0x35: "Escape"
    ]
}

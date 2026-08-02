import AppKit
import Carbon.HIToolbox
import VelloCore

/// Registers a system-wide hotkey through Carbon, which works inside the App Sandbox
/// and does not require Accessibility permission.
@MainActor
final class HotKeyManager {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private var hotKeyRef: EventHotKeyRef?
    private var identifier: UInt32?

    /// Four-character code identifying Vello's hotkeys.
    private static let signature: OSType = 0x5645_4C4F // 'VELO'

    isolated deinit {
        unregister()
    }

    func register(_ combo: HotKeyCombo, action: @escaping () -> Void) {
        unregister()
        guard combo.isValid else { return }

        Self.installEventHandlerIfNeeded()

        let id = Self.nextID
        Self.nextID += 1

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            Self.carbonModifiers(from: combo),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            Log.app.error("Could not register the global shortcut (OSStatus \(status))")
            return
        }

        hotKeyRef = reference
        identifier = id
        Self.actions[id] = action
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let identifier {
            Self.actions[identifier] = nil
            self.identifier = nil
        }
    }

    fileprivate static func dispatch(id: UInt32) {
        actions[id]?()
    }

    private static func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    private static func carbonModifiers(from combo: HotKeyCombo) -> UInt32 {
        var modifiers: UInt32 = 0
        if combo.hasCommand { modifiers |= UInt32(cmdKey) }
        if combo.hasShift { modifiers |= UInt32(shiftKey) }
        if combo.hasOption { modifiers |= UInt32(optionKey) }
        if combo.hasControl { modifiers |= UInt32(controlKey) }
        return modifiers
    }
}

/// C callback, so it cannot capture context and must look the action up by ID.
private let hotKeyEventCallback: EventHandlerUPP = { _, event, _ in
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let id = hotKeyID.id
    Task { @MainActor in
        HotKeyManager.dispatch(id: id)
    }
    return noErr
}

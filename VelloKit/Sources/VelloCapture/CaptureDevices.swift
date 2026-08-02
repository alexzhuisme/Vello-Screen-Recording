import AVFoundation
import AppKit
import CoreGraphics
import ScreenCaptureKit
import VelloCore

public struct CaptureDisplay: Sendable, Identifiable, Equatable {
    public let id: CGDirectDisplayID
    /// Display bounds in global screen points, top-left origin.
    public let frame: CGRect
    public let scaleFactor: CGFloat
    public let localizedName: String
}

public struct CaptureWindow: Sendable, Identifiable, Equatable {
    public let id: CGWindowID
    public let title: String
    public let applicationName: String
    public let bundleIdentifier: String?
    /// Window bounds in global screen points, top-left origin.
    public let frame: CGRect
}

public struct AudioInputDevice: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
}

public enum CaptureDevices {
    /// Displays currently attached, ordered with the main display first.
    public static func displays() async throws -> [CaptureDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        return content.displays.map { display in
            let screen = NSScreen.screens.first { screen in
                screen.displayID == display.displayID
            }
            return CaptureDisplay(
                id: display.displayID,
                frame: screen?.frame ?? display.frame,
                scaleFactor: screen?.backingScaleFactor ?? 2,
                localizedName: screen?.localizedName ?? "Display \(display.displayID)"
            )
        }
        .sorted { lhs, rhs in
            if lhs.id == CGMainDisplayID() { return true }
            if rhs.id == CGMainDisplayID() { return false }
            return lhs.id < rhs.id
        }
    }

    /// On-screen windows worth offering in the picker: titled, reasonably sized,
    /// and not belonging to Vello itself.
    public static func windows() async throws -> [CaptureWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        let ownBundleID = Bundle.main.bundleIdentifier

        return content.windows.compactMap { window -> CaptureWindow? in
            guard let app = window.owningApplication,
                  app.bundleIdentifier != ownBundleID,
                  let title = window.title, !title.isEmpty,
                  window.frame.width > 50, window.frame.height > 50
            else { return nil }

            return CaptureWindow(
                id: window.windowID,
                title: title,
                applicationName: app.applicationName,
                bundleIdentifier: app.bundleIdentifier,
                frame: window.frame
            )
        }
    }

    public static func audioInputDevices() -> [AudioInputDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return session.devices.map { AudioInputDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    public static func defaultAudioInputDevice() -> AudioInputDevice? {
        guard let device = AVCaptureDevice.default(for: .audio) else { return nil }
        return AudioInputDevice(id: device.uniqueID, name: device.localizedName)
    }

    /// Turns the stored setting into a concrete device ID, resolving the
    /// system-default sentinel and dropping IDs for devices that went away.
    public static func resolveAudioDeviceID(_ stored: String?) -> String? {
        guard let stored else { return nil }
        if stored == systemDefaultAudioDeviceID {
            return defaultAudioInputDevice()?.id
        }
        let available = audioInputDevices()
        if available.contains(where: { $0.id == stored }) {
            return stored
        }
        return defaultAudioInputDevice()?.id
    }
}

public extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

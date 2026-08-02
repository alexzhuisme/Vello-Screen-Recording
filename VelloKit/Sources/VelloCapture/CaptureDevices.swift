import AVFoundation
import AppKit
import CoreGraphics
import ScreenCaptureKit
import VelloCore

public struct CaptureDisplay: Sendable, Identifiable, Equatable {
    public let id: CGDirectDisplayID
    /// Display bounds in global AppKit/SCK points (bottom-left origin).
    public let frame: CGRect
    public let scaleFactor: CGFloat
    public let localizedName: String

    public init(
        id: CGDirectDisplayID,
        frame: CGRect,
        scaleFactor: CGFloat,
        localizedName: String
    ) {
        self.id = id
        self.frame = frame
        self.scaleFactor = scaleFactor
        self.localizedName = localizedName
    }
}

public struct CaptureWindow: Sendable, Identifiable, Equatable {
    public let id: CGWindowID
    public let title: String
    public let applicationName: String
    public let bundleIdentifier: String?
    public let processID: pid_t
    /// Window bounds in global AppKit/CG points (bottom-left origin).
    public let frame: CGRect

    public init(
        id: CGWindowID,
        title: String,
        applicationName: String,
        bundleIdentifier: String?,
        processID: pid_t,
        frame: CGRect
    ) {
        self.id = id
        self.title = title
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processID = processID
        self.frame = frame
    }

    public func withFrame(_ frame: CGRect) -> CaptureWindow {
        CaptureWindow(
            id: id,
            title: title,
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            processID: processID,
            frame: frame
        )
    }
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

    /// Bundle IDs for system chrome that sits above app windows and would steal
    /// hover hits (Dock overlays, Control Center, wallpaper helpers, etc.).
    private static let excludedWindowBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.NotificationCenterUi",
        "com.apple.notificationcenterui",
        "com.apple.Wallpaper",
        "com.apple.loginwindow",
        "com.apple.Spotlight",
        "com.apple.TextInputUI",
        "com.apple.WindowManager",
        "com.apple.systemuiserver"
    ]

    /// On-screen windows worth offering in the picker. Untitled windows are kept
    /// (many Electron / IDE panels have empty titles). System chrome and high
    /// window-server layers (Dock, Magnet overlays, menu extras) are dropped.
    /// Frames are taken from `CGWindowList` so highlight bounds match what the
    /// user sees, while membership still requires an `SCWindow` (capturable).
    public static func windows() async throws -> [CaptureWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let ownBundleID = Bundle.main.bundleIdentifier
        let cgFrames = cgWindowFrames()

        return content.windows.compactMap { window -> CaptureWindow? in
            guard let app = window.owningApplication,
                  app.bundleIdentifier != ownBundleID,
                  !excludedWindowBundleIDs.contains(app.bundleIdentifier),
                  // Normal app windows are layer 0; floating panels sit slightly above.
                  (0...8).contains(window.windowLayer),
                  window.frame.width >= 32, window.frame.height >= 32
            else { return nil }

            let frame = cgFrames[window.windowID] ?? window.frame
            guard frame.width >= 32, frame.height >= 32 else { return nil }

            return CaptureWindow(
                id: window.windowID,
                title: window.title ?? "",
                applicationName: app.applicationName,
                bundleIdentifier: app.bundleIdentifier,
                processID: app.processID,
                frame: frame
            )
        }
    }

    /// Global AppKit (bottom-left) frames keyed by window number, from WindowServer.
    ///
    /// `kCGWindowBounds` uses a top-left origin on the primary display — convert
    /// before comparing with `NSEvent.mouseLocation` / `NSScreen.frame`.
    public static func cgWindowFrames() -> [CGWindowID: CGRect] {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [:] }

        var frames: [CGWindowID: CGRect] = [:]
        for entry in info {
            guard let number = entry[kCGWindowNumber as String] as? Int,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"]
            else { continue }
            frames[CGWindowID(number)] = appKitFrame(
                fromCGWindowBounds: CGRect(x: x, y: y, width: width, height: height)
            )
        }
        return frames
    }

    /// Converts Quartz window bounds (top-left origin at the primary display) into
    /// global AppKit coordinates (bottom-left origin).
    public static func appKitFrame(
        fromCGWindowBounds cgBounds: CGRect,
        primaryDisplayHeight: CGFloat? = nil
    ) -> CGRect {
        let primaryHeight = primaryDisplayHeight
            ?? NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? cgBounds.height
        return CGRect(
            x: cgBounds.origin.x,
            y: primaryHeight - cgBounds.origin.y - cgBounds.height,
            width: cgBounds.width,
            height: cgBounds.height
        )
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
